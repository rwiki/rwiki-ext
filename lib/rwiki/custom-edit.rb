require "rwiki/rddoc-section"

module RWiki

	class Page

		alias _initialize initialize
		def initialize(*args)
			_initialize(*args)
			@old_formats = []
		end

		def pop_format
			@format = @old_formats.pop unless @old_formats.empty?
		end

		alias _format= format=
		def format=(new_format)
			@old_formats.push(@format)
			self._format = new_format
		end

	end
	
	class Book

		alias _section section
    def section(name)
      @section_list.each do |sec|
				return sec if sec.match?(name, self)
      end
      return @root_section
    end

	end

	class Section

		alias _match? match?
    def match?(name, book=nil)
			_match?(name)
    end

	end

	module Custom

		class EditSection < Section

			def initialize(config, edit_page_name)
				unless config
					config = BookConfig.default.dup
					config.page = EditPage
					config.format = EditFormat
				end
				super(config, nil)
				@edit_page_name = edit_page_name
				add_prop_loader(:edit, EditPropLoader.new)
			end

			def create_page(name, book)
				pg = super
				unless @edit_page_name == name
					admin_pg_name = admin_page_name(book)
					pg.format = if admin_page?(name, book, admin_pg_name)
												AdminFormat
											elsif config_page?(name, book, admin_pg_name)
												admin_pg = admin_page(book, admin_pg_name)
												admin_pg.format.new({}).find_format(admin_pg, name)
											end
					pg.format ||= @format
				end
				pg
			end

			def match?(name, book)
				@edit_page_name == name or
					admin_or_config_page?(name, book)
			end

			private
			def edit_page(book)
#				@edit_page ||= book[@edit_page_name]
				book[@edit_page_name]
			end

			def admin_page_name(book)
				pg = edit_page(book)
				if pg.format.ancestors.include?(EditFormat)
					pg.format.new({}).admin_page_name(pg)
				else
					nil
				end
			end

			def admin_page(book, admin_pg_name=nil)
				book[admin_pg_name || admin_page_name(book)]
			end

			def admin_page?(name, book, admin_pg_name=nil)
				(admin_pg_name || admin_page_name(book)) == name
			end

			def config_page?(name, book, admin_pg_name=nil)
				admin_pg = admin_page(book, admin_pg_name)
				admin_pg and
					admin_pg.format.new({}).config_page_names(admin_pg).include?(name)
			end

			def admin_or_config_page?(name, book)
				admin_pg_name = admin_page_name(book)
				if admin_pg_name.nil?
					false
				else
					admin_page?(name, book, admin_pg_name) or
						config_page?(name, book, admin_pg_name)
				end
			end

		end

		class EditPropLoader
			def load(content)
				prop = {}
				root_section = parse(content.tree)
				prop[:section] = root_section
				prop[:fields] = root_section.section
				prop[:name] = content.name
				prop
			end

			private
			def parse(tree)
				RDDoc::Section.new_by_tree(tree)
			end

		end

		class EditPage < Page

			def set_src(v, rev, env={}, &block)
				begin
					new_src = format.new(env, &block).create_src(self, v)
					super(new_src, rev, &block)
				rescue NameError
					p format
					p format.new(env, &block)
					p format.new(env, &block).methods
					raise
				end
			end

		end

		class RDWriter
			
			HEADLINE = [
				"=",
				"==",
				"===",
				"====",
				"+",
				"++",
			]

			def initialize(name, key, children=[], &var)
				@name = name
				@key = key
				@children = children
				@var = var
			end

			def to_rd(pg, level=nil)
				rv = ""
				if @name and level
					rv << "#{HEADLINE[level]} #{@name}\n"
				end
				p @name if @var.nil?
				if @var and @key
					value = @var[@key]
					if value.kind_of?(Array)
						value.each do |v|
							rv << "* #{v}\n"
						end
					elsif not value.nil?
						rv << value
					end
				end
				level = level.succ unless level.nil?
				@children.each do |child|
					rv << child.to_rd(pg, level)
				end
				rv
			end

		end

		class EditFormat < PageFormat

			def create_src(pg, src)
				children = admin_fields(pg).collect do |type, name|
					if type and name and Type.const_defined?("#{type}Format")
						Type.const_get("#{type}Format").create_rd_writer(pg, name, &method(:var))
					else
						nil
					end
				end.compact
				rd_writer = RDWriter.new(pg.name, "admin_page_name", children) do |key|
					if key == "admin_page_name"
						val = var(key).find {|x| x !~ /\A\s*\z/}
						if val
							"((<#{val}>))\n"
						else
							""
						end
					else
						var(key).find_all {|x| x !~ /\A\s*\z/}
					end
				end
				rd_writer.to_rd(pg, 0)
			end

			def field_type(pg)
				Type::List.new(make_fields(pg), default_fields(pg), additional_fields(pg))
			end

			def admin_page_name(pg)
				prop = get_prop(pg)
				if prop and prop[:section]
					prop[:section].texts.first
				else
					nil
				end
			end

			private
			def default_fields(pg)
				admin_fields(pg).collect do |type, name|
					type += "Format"
					if Type.const_defined?(type)
							Type.const_get(type).create_type(pg, name)
						else
							nil
						end
				end.compact
			end

			def additional_fields(pg)
				5
			end

			def make_fields(pg)
				i = -1
				[
					Type::Component.new([
																Type::String.new("AdminPageName: "),
																Type::Text.new("admin_page_name",
																							 admin_page_name(pg))
															]),
					Type::Component.new(admin_fields(pg).collect do |type, name|
																type += "Format"
																if Type.const_defined?(type)
																	Type.const_get(type).create_type(pg, name, (i = i + 1))
																else
																	nil
																end
															end.compact)
				]
			end

			def get_prop(pg)
				pg.prop(:edit)
			end

			def admin_prop(pg)
				page_name = admin_page_name(pg)
				aprop = nil
				if page_name
					aprop = get_prop(pg.book[page_name])
				end
				aprop || {}
			end

			def admin_fields(pg)
				admin_section = admin_prop(pg)[:section]
				if admin_section
					admin_section.item_list.collect {|item| parse_field(item)}
				else
					[]
				end
			end

			def parse_field(item)
				item.split(":", 2)
			end

			@rhtml = {
				:edit => RWiki::ERBLoader.new('edit(pg)', 'custom-edit.rhtml'),
			}
			reload_rhtml
		end

		require "rwiki/custom-type"

		class AdminFormat < EditFormat

			OPTIONS = [
				["-", ],
				["String", ],
				["Text" ,],
				["Textarea", ],
				["Select", ],
				["MultipleSelect", "Select (ultiple)"],
				["Checkbox", ],
				["Radio", ],
			]

			COMPONENTS = 
				[
				[Type::Text, "field_name", proc {|x| x}],
				[Type::Select, "field_type",
					proc do |value|
						OPTIONS.collect do |val, label|
							Type::Option.new(val, label || val, value == val)
						end
					end,
					false
				],
			]

			DEFAULT_COMPONENTS = 
				[
				Type::Text.new("field_name", ""),
				Type::Select.new("field_type",
												 [
													 Type::Option.new("-"),
													 Type::Option.new("String"),
													 Type::Option.new("Text"),
													 Type::Option.new("Textarea"),
													 Type::Option.new("Select"),
													 Type::Option.new("MultipleSelect",
																						"select (multiple)"),
													 Type::Option.new("Checkbox"),
													 Type::Option.new("Radio"),
												 ],
												 false),
			]

			def create_src(pg, src)
				prop = get_prop(pg)
				fields = if prop and prop[:section]
									 prop[:section].item_list
								 else
									 []
								 end
				RDWriter.new(pg.name, "field") do |key|
					if key == "field"
						types, names = var("field_type"), var("field_name")
						rv = []
						names.each_with_index do |name, i|
							if types[i] and name !~ /\A\s*\z/ and
									types[i] != "-" and Type.const_defined?(types[i])
								rv << %Q!#{types[i]}:((<#{name}>))!
							end
						end
						rv
					else
						var(key)
					end
				end.to_rd(pg, 0)
			end

			def config_page_names(pg)
				get_values(pg).collect do |hash|
					hash["field_name"]
				end
			end

			def find_format(pg, name)
				get_values(pg).each do |hash| 
					return Type.const_get("#{hash['field_type']}Format") if name == hash["field_name"]
				end
				nil
			end

			private
			def additional_fields(pg)
				5
			end

			def default_fields(pg)
				[Type::Component.new(DEFAULT_COMPONENTS)]
			end

			def make_fields(pg)
				get_values(pg).collect {|value| make_component(value)}
			end

			def get_values(pg)
				values = []
				prop = get_prop(pg)
				if prop and (sec = prop[:section])
					sec.item_list.each do |item|
						type, name = item.split(":", 2)
						if type and name
							values << {
								"field_name" => name,
								"field_type" => type,
							}
						end
					end
				end
				values
			end

			def make_component(value={})
				components = COMPONENTS.collect do |type, name, *rest|
					type.new(name, *apply_value(rest, value[name]))
				end
				Type::Component.new(components)
			end

			def apply_value(array, value)
				array.collect do |x|
					if x.kind_of?(Proc)
						x.call(value)
					else
						x
					end
				end
			end

		end

	end
end

