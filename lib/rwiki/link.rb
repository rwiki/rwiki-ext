require "rwiki/custom-edit"
require "rwiki/rss-maneger"
require "rwiki/rss-page"

module RWiki
	module LinkSystem

		class << self

			def install(index_name, link_base_name, category_base_name)
				config = BookConfig.default.dup
				config.format = LinkFormat
				config.page = LinkPage
				link_sec = LinkSection.new(config, link_base_name)
				RWiki::Book.section_list.push(link_sec)
				config.format = CategoryFormat
				config.page = CategoryPage
				cat_sec = CategorySection.new(config, category_base_name, link_sec)
				RWiki::Book.section_list.push(cat_sec)
				config.format = IndexFormat
				config.page = IndexPage
				index_sec = IndexSection.new(config, index_name, link_sec, cat_sec)
				RWiki::Book.section_list.push(index_sec)
			end

		end

		class IndexSection < ::RWiki::Section

			attr_reader :name, :link_section, :category_section

			def initialize(config, name, link_section, category_section)
				super(config, name)
				@name = name
				@link_section = link_section
				@link_section.index_section = self
				@category_section = category_section
				@category_section.index_section = self
				add_prop_loader(:index, PropLoader.new)
			end

			def new_link_page_name(book)
				@link_section.new_page_name(book)
			end

			def new_category_page_name(book)
				@category_section.new_page_name(book)
			end

			def index_page_name
				@name
			end

		end

		module LinkSectionMixIn
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

			attr_accessor :index_section, :category_section, :base_name, :pattern

			def initialize(config, base_name)
				super(config, /\A#{Regexp.escape(base_name)}(\d+)\z/)
				@base_name = base_name
				add_prop_loader(:link, PropLoader.new)
			end

		end

		class CategorySection < ::RWiki::Section

			include LinkSectionMixIn

			attr_reader :link_section, :base_name, :pattern
			attr_accessor :index_section

			def initialize(config, base_name, link_section)
				super(config, /\A#{Regexp.escape(base_name)}(\d+)\z/)
				@base_name = base_name
				@link_section = link_section
				@link_section.category_section = self
				add_prop_loader(:category, PropLoader.new)
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

			attr_accessor :dirty

			def edit_html(env={}, &block)
				format = @format.new(env, &block)
				mode, = block ? block.call('mode') : nil

				case mode
				when 'default'
					format.edit(self)
				else
					format.custom_edit(self)
				end
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
				@dirty = false
			end

			def property
				@property ||= generate_property
			end

			def index_page
				@book[index_page_name]
			end

			def all_category
				index_page.categories
			end

			def all_links
				index_page.link_pages
			end

			def dirty?
				return true if @dirty
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

			private
			def dispatch_view_html(format, &block)
				mode, = block ? block.call('mode') : nil
				if mode.nil? or /\A\s*\z/ =~ mode
					mode = "custom"
				end
				
				if format.respond_to?("#{mode}_view")
					format.send("#{mode}_view", self)
				else
					format.view(self)
				end
			end

			def update_index_page_src
				ind_pg = index_page
				ind_pg.src = ind_pg.format.new().create_src(ind_pg, '')
			end

			def update_category_page_src(cat_pg)
				cat_pg.src = cat_pg.format.new().create_src(cat_pg, '')
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
				base_name = section.base_name
				rv = []
				i = 0
				loop do
					pg = @book[base_name + i.to_s]
					break if pg.src.nil?
					rv << pg
					i += 1
				end
				rv
			end

		end

		class CategoryPage < ::RWiki::Custom::EditPage

			include LinkPageMixIn

			def link_pages
				get_property(:links, [])
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
				if dirty?
					self.src = format.make_src(self) 
				end
				dispatch_view_html(format, &block)
			end

			private
			def index_page_name
				@section.index_section.index_page_name
			end

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

			def index_page_name
				@section.index_section.index_page_name
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
				dispatch_view_html(format, &block)
			end

			private
			def property_key
				:link
			end

			def getting_property_infos
				[
					[:url, "texts", get_first_element_proc],
					[:rss, "texts", get_first_element_proc],
					[:categories, "item_list", collect_page_proc],
				]
			end

		end
		
		class IndexPage < ::RWiki::Custom::EditPage

			include LinkPageMixIn

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
				end
			end

			def view_html(env={}, &block)
				format = @format.new(env, &block)
				if dirty?
					self.src = format.make_src(self) 
				end
				dispatch_view_html(format, &block)
			end

			def find_all_category(&block)
				categories.find_all(&block)
			end

			private
			def index_page_name
				@section.name
			end

			def property_key
				:index
			end

			def getting_property_infos
				[
					[:categories, "item_list", collect_page_proc],
					[:links, "item_list", collect_page_proc],
				]
			end

		end
		
		class PageFormat < ::RWiki::PageFormat
			def create_src(pg, src)
				make_src(pg)
			end

			private

			include ::RWiki::RSS::FormatUtils

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
			}
			
			reload_rhtml

		end

		class CategoryFormat < PageFormat
			private
			def default_recent_changes_number
				10
			end

			def added_recent_changes_number
				30
			end

			def link_navis(pg)
				index_pg = pg.index_page
				[
					make_anchor(ref_name(index_pg.name), index_pg.title, index_pg.modified),
				]
			end

			@rhtml = {
				:custom_view => ::RWiki::ERbLoader.new("custom_view(pg)", "link_category.rhtml"),
				:custom_edit => ::RWiki::ERbLoader.new("custom_edit(pg)", "link_category_edit.rhtml"),
				:make_src => ::RWiki::ERbLoader.new("make_src(pg)", "link_category.rrd"),
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
				:make_src => ::RWiki::ERbLoader.new("make_src(pg)", "link_link.rrd"),
			}
			reload_rhtml
		end

		class IndexFormat < PageFormat
			private
			def default_recent_changes_number
				10
			end

			def added_recent_changes_number
				30
			end

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
					make_anchor(ref_name(new_category_page_name(pg), {}, "edit"),
											titles[:category] || "Register new category",
											nil),
					make_anchor(ref_name(new_link_page_name(pg), {}, "edit"),
											titles[:link] || "Register new link",
											nil),
					make_anchor(ref_name(name, {"mode" => "refine"}),
											titles[:refine] || "Refine category",
											modified),
					make_anchor(ref_name(name, {"mode" => "search"}),
											titles[:search] || "Search",
											modified),
				]
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
				:search_view => ::RWiki::ERbLoader.new("search_view(pg)", "link_index_search.rhtml"),
				:refine_view => ::RWiki::ERbLoader.new("refine_view(pg)", "link_index_refine.rhtml"),
				:custom_edit => ::RWiki::ERbLoader.new("custom_edit(pg)", "link_index_edit.rhtml"),
				:make_src => ::RWiki::ERbLoader.new("make_src(pg)", "link_index.rrd"),
			}
			reload_rhtml

		end

	end
end


