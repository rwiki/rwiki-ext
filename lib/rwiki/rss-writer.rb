require "time"
require "rwiki/rss-page"

RWiki::Request::COMMAND << 'rss'

module RWiki
  Version.regist('rss-writer', '2003-08-14')

  module RSS
    class Writer < PageFormat

			include FormatUtils

      if const_defined?("DESCRIPTION")
        @@description = DESCRIPTION
      else
        @@description = @@title
      end

      if RSS.const_defined?("IMAGE")
        @@image = IMAGE
      else
        @@image = nil
      end

      def navi_view(pg, title, referer)
        %Q[<span class="navi">[<a href="#{ ref_name(pg.name, {'navi' => pg.name}, 'rss') }">#{ h title }</a>]</span>]
      end

      private
      @rhtml = {
        :rss => ERBLoader.new('rss(pg)', 'recent1.0.rrdf')
      }
      reload_rhtml
    end
  end

  class Front
    def rss_view(env = {}, &block)
     RSS::Writer.new(env, &block).rss(@book['rss1.0'])
    end
  end

  install_page_module('rss1.0', RWiki::RSS::Writer, 'RSS 1.0')
end
