require "rwiki/rss-page"
require "rwiki/rss-maneger"

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
				include FormatUtils

				@rhtml = { :view => ERbLoader.new('view(pg)', 'rss-recent.rhtml') }
				reload_rhtml
			end
			
		end
	end
end
