require "rwiki/rss-maneger"
require "rwiki/rss-page"

module RWiki
	module RSS
		module Recent

			class Section < RWiki::Section

				def initialize(config, pattern)
					super(config, pattern)
					add_prop_loader(:rss, PropLoader.new)
					add_default_src_proc(method(:default_src))
				end

				RWiki::ERbLoader.new('default_src(name)', 'rss-recent.erd').load(self)
			end

			class PageFormat < RWiki::PageFormat
				private
				def make_item_anchor(channel, item, name)
					name = channel.title if name.to_s =~ /\A\s*\z/
					%Q|<a href="#{h channel.link.strip}">#{h name}</a>\n| <<
					%Q|<a href="#{h item.link.strip}">#{h item.title}</a>|
				end
				alias ia make_item_anchor
				
				def make_item_anchor_and_modified(channel, item, name)
					ia(channel, item, name) << %Q| (#{h modified(item.dc_date)})|
				end
				alias iam make_item_anchor_and_modified
				
				def make_uri_anchor(uri, name)
					%Q|<a href="#{h uri}">#{h name} : #{h uri}</a>|
				end
				alias ua make_uri_anchor
				
				@rhtml = { :view => ERbLoader.new('view(pg)', 'rss-recent.rhtml') }
				reload_rhtml
			end
			
		end
	end
end
