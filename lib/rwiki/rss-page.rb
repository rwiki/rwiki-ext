require "rwiki/rddoc"

module RWiki
	module RSS
		
		MINIMUM_EXPIRE = 60 * 60 unless const_defined?(:MINIMUM_EXPIRE)
		EXPIRE = 2 * 60 * 60 unless const_defined?(:EXPIRE)
		DISPLAY = true unless const_defined?(:DISPLAY)
		DISPLAY_PAGES = 5 unless const_defined?(:DISPLAY_PAGES)
		DISPLAY_CHARACTERS = 20 unless const_defined?(:DISPLAY_CHARACTERS)
		TRUE_VALUES = ["�Ϥ�", "yes", "true"] unless const_defined?(:TRUE_VALUES)

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
						when 'cache', '����å���'
							CacheSection.new(prop).apply_Section(content)
						when 'display', 'ɽ��'
							DisplaySection.new(prop).apply_Section(content)
						when 'servers', '������'
							URISection.new(prop).apply_Section(content)
						when 'thread', '����å�'
							ThreadSection.new(prop).apply_Section(content)
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

		class CacheSection < PropSection
			def apply_Prop(key, value)
				super(key, value)
				case key.downcase
				when 'ͭ������', 'ͭ������', 'expire'
					@prop[:expire] = value.to_i * 60
					@prop[:expire] = EXPIRE if @prop[:expire] < MINIMUM_EXPIRE
				end
			end
		end

		class DisplaySection < PropSection
			def apply_Prop(key, value)
				super(key, value)
				case key.downcase
				when 'ɽ��', 'display'
					if TRUE_VALUES.include?(value.strip.downcase)
						@prop[:display] = true
					else
						@prop[:display] = false
					end
				when '���', 'pages'
					@prop[:pages] = value.to_i
					@prop[:pages] = DISPLAY_PAGES if @prop[:pages].zero?
				when 'ʸ����', 'characters'
					@prop[:characters] = value.to_i
					if @prop[:characters].zero?
						@prop[:characters] = DISPLAY_CHARACTERS
					end
				end
			end
		end

		class ThreadSection < PropSection
			def apply_Prop(key, value)
				super(key, value)
				case key.downcase
				when '�Ȥ�', 'use'
					if TRUE_VALUES.include?(value.strip.downcase)
						@prop[:use_thread] = true
					else
						@prop[:use_thread] = false
					end
				end
			end
		end

		class URISection < PropSection
			def initialize(*args)
				super
				@prop[:uri] = {}
			end

			def apply_Prop(key, value)
				super(key, value)
				@prop[:uri][value] = key
			end
		end

		module FormatUtils

			def make_anchor(href, name, time=nil)
				%Q[<a href="#{h href}" title="#{h name} #{make_modified(time)}" class="#{modified_class(time)}">#{h name}</a>]
			end

			def make_channel_anchor(channel, name=nil)
				name = channel.title if name.to_s =~ /\A\s*\z/
				make_anchor(channel.link.strip, name, channel.dc_date)
			end
			alias ca make_channel_anchor

			def make_item_anchor(item)
				make_anchor(item.link.strip, item.title, item.dc_date)
			end
			alias ia make_item_anchor

			def make_modified(date)
				%Q[(#{h modified(date)})]
			end

			def make_anchors_and_modified(channel, item, name=nil)
				"#{ca(channel, name)}: #{ia(item)} #{make_modified(item.dc_date)}"
			end
			alias am make_anchors_and_modified
			
			def make_uri_anchor(uri, name)
				%Q|<a href="#{h uri}">#{h name} : #{h uri}</a>|
			end
			alias ua make_uri_anchor
		end

	end
end
