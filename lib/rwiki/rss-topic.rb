require "rwiki/rss-maneger"
require "rwiki/rss-page"

require "nkf"

class String
	unless respond_to?(:shorten)
		def shorten(len=120)

			nkf_args = nil
			case RWiki::KCode.charset
			when 'euc-jp'
				nkf_args = '-edXm0'
			when 'Shift_JIS'
				nkf_args = '-sdXm0'
			else
			end

			if nkf_args
				lines = NKF::nkf("-e -m0 -f#{len}", self.gsub(/\n/, ' ')).split(/\n/)
				lines[0].concat('...') if lines[0] and lines[1]
				lines[0]
			else
				rv = self[0...len]
				rv.concat("...") if self.size > 120
				rv
			end
		end
	end
end

module RWiki
	module RSS

		module Topic

			extend ERB::Util

			class << self

				@@lang = ::RWiki::PageFormat.module_eval('@@lang')

				def clear
					@@maneger = ::RWiki::RSS::Maneger.new
					@@topics = {}
					@@number = DISPLAY_NUMBER
					@@characters = DISPLAY_CHARACTERS
					@@use_thread = false
					@@display = false
				end

				def forget(expire)
					::RWiki::RSS::Maneger.forget(expire)
				end

				def use_thread() @@use_thread end
				def use_thread=(new_value) @@use_thread = new_value end
				def number() @@number end
				def number=(new_value) @@number = new_value end
				def characters() @@characters end
				def characters=(new_value) @@characters = new_value end
				def display() @@display end
				def display=(new_value) @@display = new_value end

				def add_topic(uri, charset, name, expire)
					@@topics[uri] = [charset, name, expire]
				end
				
				def topics
					return '' unless @@display
						
					if @@use_thread
						arg = @@topics.collect {|uri, values| [uri, *values]}
						@@maneger.parallel_parse(arg)
					else
						@@topics.each do |uri, values|
							@@maneger.parse(uri, *values)
						end
					end
						
					rv = pre_html

					@@maneger.each do |uri, channel, items, name, time|
						if @@topics.has_key?(uri) and !items.empty?
							rv << %Q! <div class="rss_topic_item">\n! <<
								%Q! <span class="rss_topic_title">! <<
								%Q!#{tta(channel, name)}(#{time})</span>\n!
							items[0...@@number].each do |item|
								rv << %Q! <span class="rss_topic_content">! <<
									%Q![#{ttia(item, @@characters)}]</span>\n!
							end
							rv << %Q! </div>\n!
						end
					end

					rv << post_html

					rv
				end

				private
				def make_topic_title_anchor(channel, name)
					name = channel.title if name.to_s =~ /\A\s*\z/
					%Q!<a href="#{h channel.link.to_s.strip}">#{h name}</a>!
				end
				alias tta make_topic_title_anchor
				
				def make_topic_item_anchor(item, characters)
					href = h(item.link.to_s.strip)
					rv = %Q!<a href="#{href}">#{h item.title.to_s}</a>!
					desc = item.description
					if desc
						rv << %Q! : #{desc.shorten(characters)} <a href="#{href}">more</a>!
					end
					rv
				end
				alias ttia make_topic_item_anchor
				
				def pre_html
					%Q|<div class="rss_topic">\n|
				end
					
				def post_html
					%Q|</div>|
				end

			end

			clear

			class Section < RWiki::Section
				def initialize(config, pattern)
					super(config, pattern)
					add_prop_loader(:rss, PropLoader.new)
					add_default_src_proc(method(:default_src))
				end

				RWiki::ERbLoader.new('default_src(name)', 'rss-topic.erd').load(self)
			end


			class PageFormat < RWiki::PageFormat
				private
				@rhtml = { :view => ERbLoader.new('view(pg)', 'rss-topic.rhtml') }
				reload_rhtml
			end

		end

	end
end
