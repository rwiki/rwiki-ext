require "rwiki/rddoc"

module RWiki
	module RSS
		
		MINIMUM_EXPIRE = 60 * 60 unless const_defined?(:MINIMUM_EXPIRE)
		EXPIRE = 2 * 60 * 60 unless const_defined?(:EXPIRE)
		DISPLAY = true unless const_defined?(:DISPLAY)
		DISPLAY_NUMBER = 5 unless const_defined?(:DISPLAY_NUMBER)
		DISPLAY_CHARACTERS = 20 unless const_defined?(:DISPLAY_CHARACTERS)
		TRUE_VALUES = ["はい", "yes", "true"] unless const_defined?(:TRUE_VALUES)

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
						when 'cache', 'キャッシュ'
							CacheSection.new(prop).apply_Section(content)
						when 'display', '表示'
							DisplaySection.new(prop).apply_Section(content)
						when 'servers', 'サーバ'
							URISection.new(prop).apply_Section(content)
						when 'thread', 'スレッド'
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
				when '有効期間', '有効期限', 'expire'
					@prop[:expire] = value.to_i * 60
					@prop[:expire] = EXPIRE if @prop[:expire] < MINIMUM_EXPIRE
				end
			end
		end

		class DisplaySection < PropSection
			def apply_Prop(key, value)
				super(key, value)
				case key.downcase
				when '表示', 'display'
					if TRUE_VALUES.include?(value.strip.downcase)
						@prop[:display] = true
					else
						@prop[:display] = false
					end
				when '件数', 'number'
					@prop[:number] = value.to_i
					@prop[:number] = DISPLAY_NUMBER if @prop[:number].zero?
				when '文字数', 'characters'
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
				when '使う', 'use'
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

	end
end
