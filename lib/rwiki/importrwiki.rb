require 'time'
require 'socket'

require 'rwiki/importwiki'
require 'rwiki/soap-driver'

RWiki::Version.regist('ImportRWiki', '2003-05-16')

module RWiki
	module ImportWiki
		module RWiki

			class Connector < BaseConnector
				include MonitorMixin

				DRB_SPLIT_RE = /\Adruby:\/\/([a-zA-z._\-]*)?:(\d+)/

				def self.parse_uri(uri)
					uri =~ DRB_SPLIT_RE
					drb_host = $1
					drb_port = $2.to_i
				
					if drb_host.empty?
						drb_host = Socket.gethostbyname(Socket.gethostname)[0]
					else
						drb_host = Socket.gethostbyname(drb_host)[0]
					end

					[drb_host, drb_port, "druby://#{drb_host}:#{drb_port}"]
				end
					
				@@drb_host, @@drb_port, @@drb_uri = parse_uri(::RWiki::DRB_URI)

				def initialize(uri, encoding)
					super
					@modified = {}
					@local = false
					@front = nil

					log_dir = nil
					if ::RWiki::SOAP.const_defined?(:LOG_DIR)
						log_dir = ::RWiki::SOAP::LOG_DIR
					end
					@driver = ::RWiki::SOAP::Driver.new(log_dir, @uri.to_s)

					begin
						drb_host, drb_port = @driver.drb_host_and_port
						if @@drb_host == drb_host and @@drb_port == drb_port
							synchronize do
								@local = true
								ObjectSpace.each_object(DRb::DRbServer) do |o|
									if @front.nil? or
											[@@drb_host, @@drb_port, @@drb_uri] == parse_uri(o.uri)
										@front = o.front
									end
								end
								@called = false
							end
						end
					rescue ::SOAP::Error
						@driver = nil
					end

				end

				def submit(name, src)
					if @local
						synchronize do 
							unless @called
								page = @front[page_name(name)]
								page.src = src
								@called = true
							end
						end
					elsif !@driver.nil?
						@driver.copy(name, src) unless @driver.nil?
					end
					set_modified(name)
				end

				def fetch(name)
					set_modified(name)
					if @local
						synchronize do
							@called = false
							@front[page_name(name)].src
						end
					elsif !@driver.nil?
						@driver.src(name)
					end
				end

				def revision(name)
					modified(name).to_s
				end

				def modified(name)
					synchronize do
						unless @modified.has_key?(name)
							set_modified(name)
						end
					end
					@modified[name]
				end

				private
				def set_modified(name)
					synchronize do
						if @local
							begin
								@modified[name] = @front.page(page_name(name)).modified.localtime
							rescue NameError
							end
						elsif !@driver.nil?
							@modified[name] = Time.parse(@driver.modified(name).to_s).localtime
						end
					end
				end

			end

		end

		install_wiki("RWiki", RWiki::Connector)

	end
end

