require "net/http"

require "rwiki/importwiki"
require "rwiki/rd2wiliki-lib"

RWiki::Version.regist('ImportWiLiKi', '2003-05-16')

module RWiki
	module ImportWiki
		module WiLiKi

			class Connector < BaseConnector

				HTTP_HEADER = {
					"User-Agent" => "RWiki's ImportWiLiKi"
				}

				GET_LINE_RE = /[^\n]*\n/

				def initialize(uri, encoding)
					super
					@title = {}
					@mtime = {}
				end

				def submit(name, src, log_message)
					Net::HTTP.start(@uri.host, @uri.port || 80) do |http|
						path = @uri.path

						mtime = @mtime[name]

						data = "commit=true&c=c&p=#{page_name(name)}&mtime=#{mtime}&"
						tree = RD::RDTree.new("=begin\n#{src}\n=end\n")
						visitor = RD::RD2WiLiKiVisitor.new
						data << "content=#{escape(visitor.visit(tree))}&"
						data << "logmsg=#{escape(log_message)}"
						
						res = http.request_post(path, data, HTTP_HEADER)
					end
				end

				def fetch(name)
					rv = nil
					Net::HTTP.start(@uri.host, @uri.port || 80) do |http|
						path = @uri.path
						path += "?c=lv&p=#{page_name(name)}"
						req = http.request_get(path, HTTP_HEADER)
						raise InvalidResourceError unless req.code == "200"

						title = req.body.slice!(GET_LINE_RE) # title
						raise InvalidResourceError unless title =~ /\Atitle:\s*(\S+)\s*\z/
						@title[name] = $1

						req.body.slice!(GET_LINE_RE) # wiliki-lwp-version

						mtime = req.body.slice!(GET_LINE_RE) # mtime
						raise InvalidResourceError unless mtime =~ /\Amtime:\s*(\d+)\s*\z/
						@mtime[name] = $1

						req.body.slice!(GET_LINE_RE) # Empty line

						rv = req.body
					end
					rv 
				end

				def revision(name)
					begin
						fetch(name) unless @mtime.has_key?(name)
					rescue InvalidResourceError
					end
					@mtime[name]
				end

				def modified(name)
					begin
						fetch(name) unless @mtime.has_key?(name)
					rescue InvalidResourceError
					end
					Time.at(@mtime[name].to_i).localtime rescue nil
				end

			end

		end

		install_wiki("WiLiKi", WiLiKi::Connector)

	end
end

