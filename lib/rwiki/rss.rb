require "rwiki/rss-recent"
require "rwiki/rss-topic"

RWiki::Version.regist("rw-rss", "2003-8-04")

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
		class Writer < PageFormat
			if const_defined?("DESCRIPTION")
				@@description = DESCRIPTION
			else
				@@description = @@title
			end
			
			def navi_view(pg, title, referer)
				%Q!<span class="navi">[<a href="#{ ref_name(pg.name, {}, 'rss') }">#{ h title }</a>]</span>!
			end

			private
			@rhtml = {
				:view => ERbLoader.new('view(pg)', 'recent1.0.rrdf')
			}
			reload_rhtml
		end

		class PageFormat < RWiki::BookConfig.default.format
			private
			def make_topic_title_anchor(channel, name)
				name = channel.title if name.to_s =~ /\A\s*\z/
				%Q!<a href="#{h channel.link.to_s.strip}">#{h name}</a>!
			end
			alias tta make_topic_title_anchor
			
			def make_topic_item_anchor(item, characters)
				href = h(item.link.to_s.strip)
				rv = %Q!<a href="#{href}">#{h item.title.to_s}</a>!
				rv << %Q|(#{h modified(item.dc_date)})|
				desc = item.description
				if desc
					rv << %Q! : #{h(desc.shorten(characters))} <a href="#{href}">more</a>!
				end
				rv
			end
			alias ttia make_topic_item_anchor
			
			@rhtml = {
				:navi => RWiki::ERbLoader.new('navi(pg)', 'rss-navi.rhtml'),
#				:footer => RWiki::ERbLoader.new('footer(pg)', 'rss-footer.rhtml')
			}
			reload_rhtml
		end

		def install()
			recent_section = Recent::Section.new(nil, /\Arss_recent\z/)
			RWiki::Book.section_list.push(recent_section)
			topic_section = Topic::Section.new(nil, /\Arss_topic\z/)
			RWiki::Book.section_list.push(topic_section)
			RWiki::BookConfig.default.format = PageFormat
			RWiki::Request::COMMAND << 'rss'
		end
		module_function :install
	end

	install_page_module('rss1.0', RWiki::RSS::Writer, 'RSS 1.0')
	install_page_module('rss_recent', RWiki::RSS::Recent::PageFormat, 'RSS Recent')
	install_page_module('rss_topic', RWiki::RSS::Topic::PageFormat, 'RSS Topic')

end

RWiki::RSS.install
