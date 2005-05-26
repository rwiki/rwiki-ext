require "rwiki/rss/page"

module RWiki
  module RSS
    module Recent

      class Section < RWiki::Section

        def initialize(config, pattern)
          super(config, pattern)
          add_prop_loader(:rss, PropLoader.new)
          add_default_src_proc(method(:default_src))
        end

        path = %w(rss recent default_src.erd)
        ERBLoader.new('default_src(name)', path).load(self)
      end

      class PageFormat < RWiki::PageFormat
        private
        include FormatUtils

        @rhtml = {
          :view => ERBLoader.new('view(pg)', %w(rss recent view.rhtml)),
        }
        reload_rhtml
      end
      
    end
  end
end
