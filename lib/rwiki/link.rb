require "rwiki/custom-edit"
require "rwiki/rss-maneger"
require "rwiki/rss-page"

module RWiki
	module LinkSystem

		MINIMUM_DIRTY_TIME = 60 * 60 # 1 hour

		class << self

			def install(index_name, link_base_name, category_base_name, group_base_name, default_mode="custom")
				config = BookConfig.default.dup
				config.format = LinkFormat
				config.page = LinkPage
				link_sec = LinkSection.new(config, link_base_name)
				RWiki::Book.section_list.push(link_sec)
				config.format = CategoryFormat
				config.page = CategoryPage
				cat_sec = CategorySection.new(config, category_base_name, link_sec)
				RWiki::Book.section_list.push(cat_sec)
				config.format = GroupFormat
				config.page = GroupPage
				grp_sec = GroupSection.new(config, group_base_name, cat_sec)
				RWiki::Book.section_list.push(grp_sec)
				config.format = IndexFormat
				config.page = IndexPage
				index_sec = IndexSection.new(config, index_name, link_sec, cat_sec, grp_sec, default_mode)
				RWiki::Book.section_list.push(index_sec)
			end

		end

		class IndexSection < ::RWiki::Section

			attr_reader :name, :link_section, :category_section,
					:group_section, :default_mode

			def initialize(config, name, link_section, category_section, group_section, default_mode)
				super(config, name)
				@name = name
				@link_section = link_section
				@link_section.index_section = self
				@category_section = category_section
				@category_section.index_section = self
				@group_section = group_section
				@group_section.index_section = self
				@default_mode = default_mode
				add_prop_loader(:index, PropLoader.new)
			end

			def new_link_page_name(book)
				@link_section.new_page_name(book)
			end

			def new_category_page_name(book)
				@category_section.new_page_name(book)
			end

			def new_group_page_name(book)
				@group_section.new_page_name(book)
			end

			def index_page_name
				@name
			end

		end

		module LinkSectionMixIn
			
			attr_accessor :index_section

			def default_mode
				if index_section
					index_section.default_mode
				else
					nil
				end
			end

			def new_page_name(pages)
				page_numbers = pages.collect do |page|
					md = @pattern.match(page.name)
					if md and !page.empty?
						md[1].to_i
					else
						-1
					end
				end

				@base_name +
					if page_numbers.empty?
						"0"
					else
						page_numbers.max.succ.to_s
					end
			end
		end

		class LinkSection < ::RWiki::Section

			include LinkSectionMixIn

			attr_accessor :category_section
			attr_reader :base_name, :pattern

			def initialize(config, base_name)
				super(config, /\A#{Regexp.escape(base_name)}(\d+)\z/)
				@base_name = base_name
				add_prop_loader(:link, PropLoader.new)
			end

		end

		class CategorySection < ::RWiki::Section

			include LinkSectionMixIn

			attr_accessor :group_section
			attr_reader :link_section, :base_name, :pattern

			def initialize(config, base_name, link_section)
				super(config, /\A#{Regexp.escape(base_name)}(\d+)\z/)
				@base_name = base_name
				@link_section = link_section
				@link_section.category_section = self
				add_prop_loader(:category, PropLoader.new)
			end

		end

		class GroupSection < ::RWiki::Section

			include LinkSectionMixIn

			attr_reader :category_section, :base_name, :pattern

			def initialize(config, base_name, category_section)
				super(config, /\A#{Regexp.escape(base_name)}(\d+)\z/)
				@base_name = base_name
				@category_section = category_section
				@category_section.group_section = self
				add_prop_loader(:group, PropLoader.new)
			end

		end

		class PropLoader
			def load(content)
				doc = Document.new(content.tree)
				prop = doc.to_prop
				prop[:name] = content.name
				prop
			end
		end
			
		class Document
				
			def initialize(tree)
				begin
					@section = RDDoc::Section.new_by_tree(tree)
				rescue
				end
			end
				
			def to_prop
				prop = {}
				if @section
					prop[:top_level] = @section
					prop[:categories] =
						@section.item_list_elements.collect do |elem|
							elem.find {|e| e.kind_of?(RD::Reference)}
						end.compact.collect do |ref|
							ref.collect{|e| e.to_label} # [page_name, title]
						end
				end
				prop
			end
		end

		module LinkPageMixIn

			def edit_html(env={}, &block)
				dispatch_edit_html(@format.new(env, &block), &block)
			end

			def title
				get_property(:title, @name) do |value|
					/\A\s*\z/ !~ value.to_s
				end
			end

			def description
				get_property(:description)
			end

			def descriptions
				get_property(:descriptions, [])
			end

			def forget
				@property = nil
			end

			def property
				@property ||= generate_property
			end

			def index_page
				@book[index_page_name]
			end

			def index_page_name
				index_section.name
			end

			def all_category
				index_page.categories
			end

			def all_links
				index_page.link_pages
			end

			def dirty?
				return false if (Time.new - self.modified) < MINIMUM_DIRTY_TIME
				newer = hot_links[0]
				return true if newer.nil?
				return false unless @book.include_name?(newer)
				mod = @book[newer].modified || Time.at(1)
				return false unless mod > self.modified
				return true
      end

			def set_src(*args)
				super
				forget
			end

			def mode(&block)
				mod, = block ? block.call('mode') : nil
				if mod.nil? or /\A\s*\z/ =~ mod
					mod = default_mode
				end
				mod
			end

			def default_mode
				index_section.default_mode
			end

			def maneger
				@maneger ||= ::RWiki::RSS::Maneger.new
			end

			private
			def dispatch_html(html_type, format, &block)
				method_name = "#{mode(&block)}_#{html_type}"
				unless format.respond_to?(method_name)
					method_name = html_type
				end
				format.send(method_name, self, &block)
			end

			def dispatch_view_html(format, &block)
				dispatch_html("view", format, &block)
			end

			def dispatch_edit_html(format, &block)
				dispatch_html("edit", format, &block)
			end

			def update_page_src(pg, format=nil)
				format ||= pg.format.new()
				made_src = format.make_src(pg).chomp
				pg.src = made_src if pg.src != made_src
			end

			def update_index_page_src
				update_page_src(index_page)
			end

			def update_category_page_src(cat_pg)
				update_page_src(cat_pg)
			end

			def get_property(key, default_value=nil, &validation)
				rv = property[key]
				rv = nil if validation and !validation.call(rv)
				rv || default_value
			end

			def generate_property
				rv ||= {}
				pr = prop(property_key)
				if pr and pr[:top_level]
					rd_section = pr[:top_level]
					rv[:title] = rd_section.name
					rv[:description] = rd_section.texts.join("\n\n")
					rv[:descriptions] = rd_section.texts
					rd_sections = rd_section.sections
					getting_property_infos.each_with_index do |get_info, i|
						sec = rd_sections[i]
						if sec 
							key, selector, after_proc = get_info
							rv[key] = sec.send(selector)
							rv[key] = after_proc.call(rv[key])
						end
					end
				end
				rv
			end

			def collect_page_proc
				proc do |names|
					names.collect{|name| @book[name]}
				end
			end

			GET_FIRST_ELEMENT_PROC = proc {|items| items.first}
			def get_first_element_proc
				GET_FIRST_ELEMENT_PROC
			end

			def find_all_page(section)
				@section.db.find_all do |page_name|
					section.match?(page_name) and !@book[page_name].empty?
				end.collect do |page_name|
					@book[page_name]
				end
			end

		end

		class GroupPage < ::RWiki::Custom::EditPage

			include LinkPageMixIn

			VALID_REFINE_TYPE = %w(and or)
			DEFAULT_REFINE_TYPE = "and"

			def refine_type
				ref_type = get_property(:refine_type)
				if VALID_REFINE_TYPE.include?(ref_type)
					ref_type
				else
					DEFAULT_REFINE_TYPE
				end
			end

			def categories
				get_property(:categories, [])
			end

			def grouped_categories
				cat_sec = @section.category_section
				@revlinks.find_all do |name|
					cat_sec.match?(name)
				end.compact.uniq.collect do |name|
					@book[name]
				end
			end

			def link_pages
				refine_funcname = if refine_type == "and" then "&" else "|" end
				link_pgs = if refine_type == "and" and not categories.empty?
										 categories.first.link_pages
									 else
										 []
									 end
				categories.each do |cat_pg|
					link_pgs = link_pgs.send(refine_funcname, cat_pg.link_pages)
				end
				link_pgs.delete_if {|pg| pg.modified.nil?}
				link_pgs.uniq! if refine_type == "and"
				link_pgs.sort! {|x, y| x.title <=> y.title}
				link_pgs
			end

			def set_src(*args)
				super
				update_index_page_src
			end

			def view_html(env={}, &block)
				format = @format.new(env, &block)
				update_page_src(self, format) if dirty?
				dispatch_view_html(format, &block)
			end

			def index_section
				@section.index_section
			end

			private
			def property_key
				:group
			end

			def getting_property_infos
				[
					[:refine_type, "texts", get_first_element_proc],
					[:categories, "item_list", collect_page_proc],
				]
			end

		end

		class CategoryPage < ::RWiki::Custom::EditPage

			include LinkPageMixIn

			def link_pages
				get_property(:links, []).delete_if {|pg| pg.modified.nil?}
			end

			def categorized_links
				link_sec = @section.link_section
				@revlinks.find_all do |name|
					link_sec.match?(name)
				end.compact.uniq.collect do |name|
					@book[name]
				end
			end

			def set_src(*args)
				super
				update_index_page_src
			end

			def view_html(env={}, &block)
				format = @format.new(env, &block)
				update_page_src(self, format) if dirty?
				dispatch_view_html(format, &block)
			end

			def index_section
				@section.index_section
			end

			private
			def property_key
				:category
			end

			def getting_property_infos
				[
					[:links, "item_list", collect_page_proc]
				]
			end

		end
		
		class LinkPage < ::RWiki::Custom::EditPage

			include LinkPageMixIn

			def rss
				get_property(:rss)
			end

			def url
				get_property(:url)
			end

			def categories
				get_property(:categories, [])
			end

			def count
				get_property(:count)
			end

			def index_section
				@section.index_section
			end

			def category_pages
				find_all_page(@section.category_section)
			end

			def set_src(*args)
				super
				cats = categories
				if cats.empty?
					update_index_page_src
				else
 					cats.each {|cat| update_category_page_src(cat)}
				end
			end

			def view_html(env={}, &block)
				format = @format.new(env, &block)
				state = current_state
				self.src = @format.new(env){|key| state[key]}.make_src(self)
				dispatch_view_html(format, &block)
			end

			def match?(regexp)
				super(regexp) or rss_match?(regexp)
			end

			def rss_match?(regexp)
				if rss and target_rss = maneger[rss]
					regexp.match(target_rss[:name]) or
						(target_rss[:description] and
							 regexp =~ target_rss[:description]) or
						rss_item_match?(regexp, maneger.items(rss))
				else
					false
				end
			end

			private
			def rss_item_match?(regexp, items)
				items.find do |item|
					regexp =~ item.title or
						(item.description and regexp =~ item.description) or
						(item.content_encoded and regexp =~ item.content_encoded)
				end
			end

			def property_key
				:link
			end

			def getting_property_infos
				[
					[:url, "texts", get_first_element_proc],
					[:rss, "texts", get_first_element_proc],
					[:categories, "item_list", collect_page_proc],
					[:count, "texts", get_first_element_proc],
				]
			end

			def current_state
				Hash.new([]).update(
				{
					"title" => [title],
					"description" => [description],
					"url" => [url],
					"rss" => [rss],
				 	"categories" => categories.collect{|cat_pg| cat_pg.name},
					"count" => [count],
				})
			end

		end
		
		class IndexPage < ::RWiki::Custom::EditPage

			include LinkPageMixIn

      def format=(new_value)
        #p 11111
        #puts caller.join("\n")
        #p new_value
        super if new_value.instance_methods.include?("make_src")
      end

			def groups(force_recalc=false)
				if force_recalc
					find_all_page(@section.group_section)
				else
					get_property(:groups, [])
				end
			end

			def categories(force_recalc=false)
				if force_recalc
					find_all_page(@section.category_section)
				else
					get_property(:categories, [])
				end
			end

			def link_pages(force_recalc=false)
				if force_recalc
					find_all_page(@section.link_section)
				else
					get_property(:links, [])
				end.delete_if {|pg| pg.modified.nil?}
			end

			def view_html(env={}, &block)
				format = @format.new(env, &block)
				update_page_src(self, format) if dirty?
				::RWiki::RSS::Maneger.forget
				dispatch_view_html(format, &block)
			end

			def find_all_category(&block)
				categories.find_all(&block)
			end

			def find_all_group(&block)
				groupes.find_all(&block)
			end

			def index_section
				@section
			end

			private
			def property_key
				:index
			end

			def getting_property_infos
				[
					[:groups, "item_list", collect_page_proc],
					[:categories, "item_list", collect_page_proc],
					[:links, "item_list", collect_page_proc],
				]
			end

		end
		
		class PageFormat < ::RWiki::PageFormat
			def create_src(pg, src)
				if var('mode').first == pg.default_mode
					generate_src(pg, src)
				else
					src
				end
			end

			private

			include ::RWiki::RSS::FormatUtils

			def default_display_update_info
				true
			end
			def default_list_number
				3
			end

			def default_rss_description_character_number
				20
			end

			def generate_src(pg, src)
				if have_contents(pg)
					make_src(pg)
				else
					"" # delete
				end
			end

			def have_contents(pg)
				/\A\s*\z/ !~ var("title").first.to_s or
					/\A\s*\z/ !~ var("description").first.to_s
			end

			def default_escape_rd_options
				{
					:accept_textblock => false,
					:accept_slash => true,
				}
			end

			def escape_rd(str, options={})
				options = default_escape_rd_options.update(options)
				str = str.to_s
				str = str.gsub(/\(\(/, '( (').gsub(/\)\)/, ') )').gsub(/\A(=|\*|\(|:)/, %q[(('\1'))])
				unless options[:accept_slash]
					str.gsub!(/\//, "(('/'))")
				end
				unless options[:accept_textblock]
					str.gsub!(/\r?\n/, '')
				end
				str
			end
			alias er escape_rd

			@rhtml = {
				:link_navi => ::RWiki::ERbLoader.new("link_navi(pg, *args)", "link_navi.rhtml"),
				:list_recent_link => ::RWiki::ERbLoader.new("list_recent_link(pg, link_pages, *params)", "link_list_recent_link.rhtml"),
				:list_link => ::RWiki::ERbLoader.new("list_link(pg, link_pages)", "link_list_link.rhtml"),
				:dedicated_header => ::RWiki::ERbLoader.new("dedicated_header(pg, *args)", "link_dedicated_header.rhtml"),
				:dedicated_navi => ::RWiki::ERbLoader.new("dedicated_navi(pg, *args)", "link_dedicated_navi.rhtml"),
				:dedicated_footer => ::RWiki::ERbLoader.new("dedicated_footer(pg)", "link_dedicated_footer.rhtml"),
				:dedicated_list_recent_link => ::RWiki::ERbLoader.new("dedicated_list_recent_link(pg, link_pages, *params)", "link_dedicated_list_recent_link.rhtml"),
				:dedicated_list_link => ::RWiki::ERbLoader.new("dedicated_list_link(pg, link_pages, display_update_info=default_display_update_info)", "link_dedicated_list_link.rhtml"),
				:dedicated_list_category => ::RWiki::ERbLoader.new("dedicated_list_category(pg, category_pages)", "link_dedicated_list_category.rhtml"),
				:dedicated_list_group => ::RWiki::ERbLoader.new("dedicated_list_group(pg, group_pages)", "link_dedicated_list_group.rhtml"),
				:dedicated_list_detail_of_group => ::RWiki::ERbLoader.new("dedicated_list_detail_of_group(pg, group_pages)", "link_dedicated_list_detail_of_group.rhtml"),
				:dedicated_refine_form => ::RWiki::ERbLoader.new("dedicated_refine_form(pg, refine_type='and', categories=[], selected_category_names={}, have_refine_option=false)", "link_dedicated_refine_form.rhtml"),
				:dedicated_search_form => ::RWiki::ERbLoader.new("dedicated_search_form(pg, search_type='and', keywords=[], have_search_option=false)", "link_dedicated_search_form.rhtml"),
			}
			
			reload_rhtml

		end

		class CategoryFormat < PageFormat
			private
			def link_navis(pg)
				index_pg = pg.index_page
				[
					make_anchor(ref_name(index_pg.name), index_pg.title, index_pg.modified),
				]
			end

			@rhtml = {
				:custom_view => ::RWiki::ERbLoader.new("custom_view(pg)", "link_category.rhtml"),
				:custom_edit => ::RWiki::ERbLoader.new("custom_edit(pg)", "link_category_edit.rhtml"),
				:dedicated_view => ::RWiki::ERbLoader.new("dedicated_view(pg)", "link_category_dedicated.rhtml"),
				:dedicated_edit => ::RWiki::ERbLoader.new("dedicated_edit(pg)", "link_category_dedicated_edit.rhtml"),
				:make_src => ::RWiki::ERbLoader.new("make_src(pg)", "link_category.rrd"),
			}
			reload_rhtml
		end

		class GroupFormat < PageFormat
			private
			def link_navis(pg)
				index_pg = pg.index_page
				[
					make_anchor(ref_name(index_pg.name), index_pg.title, index_pg.modified),
				]
			end

			@rhtml = {
# 				:custom_view => ::RWiki::ERbLoader.new("custom_view(pg)", "link_group.rhtml"),
# 				:custom_edit => ::RWiki::ERbLoader.new("custom_edit(pg)", "link_group_edit.rhtml"),
 				:dedicated_view => ::RWiki::ERbLoader.new("dedicated_view(pg)", "link_group_dedicated.rhtml"),
 				:dedicated_edit => ::RWiki::ERbLoader.new("dedicated_edit(pg)", "link_group_dedicated_edit.rhtml"),
 				:make_src => ::RWiki::ERbLoader.new("make_src(pg)", "link_group.rrd"),
			}
			reload_rhtml
		end

		class LinkFormat < PageFormat

			private
			def link_navis(pg)
				index_pg = pg.index_page
				[
					make_anchor(ref_name(index_pg.name), index_pg.title, index_pg.modified)
				]					
			end


			def index_page(pg)
				pg.index_page
			end

			@rhtml = {
				:custom_view=> ::RWiki::ERbLoader.new("custom_view(pg)", "link_link.rhtml"),
				:custom_edit => ::RWiki::ERbLoader.new("custom_edit(pg)", "link_link_edit.rhtml"),
				:dedicated_view => ::RWiki::ERbLoader.new("dedicated_view(pg)", "link_link_dedicated.rhtml"),
				:dedicated_edit => ::RWiki::ERbLoader.new("dedicated_edit(pg)", "link_link_dedicated_edit.rhtml"),
				:make_src => ::RWiki::ERbLoader.new("make_src(pg)", "link_link.rrd"),
			}
			reload_rhtml
		end

		class IndexFormat < PageFormat
			private
			def search_pages_by_or(pages, keywords)
				keyword_re = Regexp.new(keywords.collect do |keyword|
																	Regexp.escape(keyword)
																end.join("|"), Regexp::IGNORECASE)
				pages.find_all{|pg| pg.match?(keyword_re)}
			end

			def search_pages_by_and(pages, keywords)
				keyword_res = keywords.collect{|keyword| /#{Regexp.escape(keyword)}/i}
				pages.find_all do |pg|
					res = false
					keyword_res.each do |keyword_re|
						if pg.match?(keyword_re)
							res = true
						else
							res = false
							break
						end
					end
					res
				end
			end

			def link_navis(pg, titles={}, *args)
				name = pg.name
				modified = pg.modified
				[
					make_anchor(ref_name(name),
											titles[:index] || "Index",
											modified),
				 make_anchor(ref_name(new_group_page_name(pg), {}, "edit"),
										 titles[:group] || "Register new group",
										 nil),
				 make_anchor(ref_name(new_category_page_name(pg), {}, "edit"),
										 titles[:category] || "Register new category",
										 nil),
				 make_anchor(ref_name(new_link_page_name(pg), {}, "edit"),
										 titles[:link] || "Register new link",
										 nil),
				 make_anchor(ref_name(name, {"mode" => "#{pg.mode}_refine"}),
										 titles[:refine] || "Refine category",
										 modified),
				 make_anchor(ref_name(name, {"mode" => "#{pg.mode}_search"}),
										 titles[:search] || "Search",
										 modified),
				 make_anchor(ref_name(name, {"mode" => "#{pg.mode}_help"}),
										 titles[:help] || "Help",
										 modified),
				]
			end

			def new_group_page_name(pg)
				new_page_name(pg.groups, pg.section.group_section)
			end
			
			def new_category_page_name(pg)
				new_page_name(pg.categories, pg.section.category_section)
			end
			
			def new_link_page_name(pg)
				new_page_name(pg.link_pages, pg.section.link_section)
			end

			def title(pg)
				pg.section.name
			end

			def new_page_name(pages, section)
				section.new_page_name(pages)
			end

			@rhtml = {
				:link_navi => ::RWiki::ERbLoader.new("link_navi(pg)", "link_index_navi.rhtml"),
				:custom_view => ::RWiki::ERbLoader.new("custom_view(pg)", "link_index.rhtml"),
				:custom_search_view => ::RWiki::ERbLoader.new("custom_search_view(pg)", "link_index_search.rhtml"),
				:custom_refine_view => ::RWiki::ERbLoader.new("custom_refine_view(pg)", "link_index_refine.rhtml"),
				:custom_help_view => ::RWiki::ERbLoader.new("custom_help_view(pg)", "link_index_help.rhtml"),
				:custom_edit => ::RWiki::ERbLoader.new("custom_edit(pg)", "link_index_edit.rhtml"),
				:dedicated_navi => ::RWiki::ERbLoader.new("dedicated_navi(pg)", "link_index_dedicated_navi.rhtml"),
				:dedicated_view => ::RWiki::ERbLoader.new("dedicated_view(pg)", "link_index_dedicated.rhtml"),
				:dedicated_search_view => ::RWiki::ERbLoader.new("dedicated_search_view(pg)", "link_index_dedicated_search.rhtml"),
				:dedicated_refine_view => ::RWiki::ERbLoader.new("dedicated_refine_view(pg)", "link_index_dedicated_refine.rhtml"),
				:dedicated_help_view => ::RWiki::ERbLoader.new("dedicated_help_view(pg)", "link_index_dedicated_help.rhtml"),
				:dedicated_edit => ::RWiki::ERbLoader.new("dedicated_edit(pg)", "link_index_dedicated_edit.rhtml"),
				:make_src => ::RWiki::ERbLoader.new("make_src(pg)", "link_index.rrd"),
			}
			
			reload_rhtml

		end

	end
end


