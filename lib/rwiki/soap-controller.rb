require 'socket'

require 'forwardable'
require 'drb/drb'

require 'rwiki/soap-lib'

module RWiki
	module SOAP
		
		class Controller
			extend Forwardable

			DRB_SPLIT_RE = /\Adruby:\/\/([a-zA-z._\-]*)?(?::(\d*))?/

			def_delegators(:@rwiki,
			               :find, :src, :body, :modified, :page,
			               :rd2content, :recent_changes)

			if const_defined?(:ALLOW_GET_PAGE) and ALLOW_GET_PAGE
				def_delegators(:@rwiki, :page)
			end

			def initialize(rwiki)
				@rwiki = rwiki

				@rwiki.__drburi =~ DRB_SPLIT_RE
				@drb_host = $1
				@drb_port = $2.to_i

				if @drb_host.empty?
					@drb_host = Socket.gethostbyname(Socket.gethostname)[0]
				else
					@drb_host = Socket.gethostbyname(@drb_host)[0]
				end

			end

			def allow_get_page # XML element name cann't include '?'.
				ALLOW_GET_PAGE ? true : false
			end
  
			def include(name) # XML element name cann't include '?'.
				@rwiki.include?(name)
			end

			def revision(name)
				page = @rwiki.page(name)
				page.revision
			end

			def copy(name, src)
				page = @rwiki.page(name)
				page.src = src
				name
			end
  
			def append(name, src)
				page = @rwiki.page(name)
				page.src = page.src.to_s + src
				name
			end

			def submit(name, src, rev, log_message)
				page = @rwiki.page(name)
				page.set_src(src, rev, log_message)
				name
			end
  
			def drb_host_and_port
				[@drb_host, @drb_port]
			end

		end

	end
end
