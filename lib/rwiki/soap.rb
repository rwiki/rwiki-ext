require 'rwiki/soap-driver'

RWiki::Version.regist('rw-soap', '2003-04-01')

module RWiki
	module SOAP

		class << self

			def install
				sec = Section.new(nil, /\Asoap\z/)
				RWiki::Book.section_list.push(sec)
				RWiki.install_page_module('soap', RWiki::SOAP::PageFormat, 'SOAP')
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

		class Document < RDDoc::SectionDocument
			def to_prop
				prop = {}
				each_section do |head, content|
					next unless head
					if head.level == 2
						case title = as_str(head.title).strip.downcase
						when 'entry', 'エントリー'
							EntrySection.new(prop).apply_Section(content)
						end
					end
				end
				prop
			end
		end

		class PropSection < RDDoc::PropSection
			def apply_Item(str)
				if /^([^:]*):\s*(.*)$/ =~ str
					apply_Prop($1.strip, $2.strip)
				end
			end
		end

		class EntrySection < PropSection
			def apply_Prop(display_name, uri)
				display_name = nil if display_name.empty?
				@prop[:entry] ||= {}
				@prop[:entry][uri] = display_name
			end
		end

		class Section < RWiki::Section

			def initialize(config, pattern)
				super(config, pattern)
				add_prop_loader(:soap, PropLoader.new)
				add_default_src_proc(method(:default_src))
			end

			RWiki::ERbLoader.new('default_src(name)', 'soap.erd').load(self)

		end

		class PageFormat < RWiki::PageFormat
			private
			def get_var(name, default='')
				tmp, = var(name)
				tmp || default
			end
			@rhtml = { :view => RWiki::ERbLoader.new('view(pg)', 'soap.rhtml') }
			reload_rhtml
		end

	end

end

RWiki::SOAP.install
