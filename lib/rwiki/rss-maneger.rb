require "net/http"
require "uri/generic"
require "thread"

require "rss/parser"
require "rss/1.0"
require "rss/0.9"
require "rss/dublincore"

module RWiki
	module RSS

		class Error < StandardError; end
		class InvalidResourceError < Error; end
		
		class Maneger

			VERSION = "0.0.3"
			
			HTTP_HEADER = {
				"User-Agent" => "RWiki's RSS Maneger version #{VERSION}. " <<
				"Using RSS parser version is #{::RSS::VERSION}."
			}

			@@cache = {}
			@@mutex = Mutex.new

			class << self
				
				def forget(expire)
					@@mutex.synchronize do
						@@cache.delete_if do |uri, values|
							values[:time] + expire  < Time.now
						end
					end
				end

			end

			attr_reader :invalid_uris, :invalid_resources
			attr_reader :not_include_update_info_resources

			def initialize()
				@items = []
				@invalid_uris = []
				@invalid_resources = []
				@not_include_update_info_resources = []
				@mutex = Mutex.new
			end

			def parse(uri, charset, name=nil, expire=nil)
				begin
					ur = URI.parse(uri)
					expire ||= EXPIRE

					raise URI::InvalidURIError if ur.scheme != "http"

					parsed = false

					need_update = nil

					@@mutex.synchronize do
						need_update = !@@cache.has_key?(uri) or
							((@@cache[uri][:time] + expire) < Time.now)
					end

					if need_update

						rss_source = nil
						begin
							rss_source = fetch_rss(ur)
						rescue TimeoutError,
								SocketError,
								Net::HTTPBadResponse,
								Net::HTTPHeaderSyntaxError,
								Errno::ECONNRESET # for FreeBSD
							@@mutex.synchronize do 
								@@cache[uri] = {
									:time => Time.now,
									:name => name,
									:channel => nil,
									:items => []
								}
							end
							raise InvalidResourceError
						end

						# parse RSS
						rss = nil
						begin
							rss = ::RSS::Parser.parse(rss_source, true)
						rescue ::RSS::InvalidRSSError
							rss = ::RSS::Parser.parse(rss_source, false)
							@mutex.synchronize do
								@invalid_resources << [uri, name]
							end
						end
						raise ::RSS::Error if rss.nil?
						channel = rss.channel
						raise ::RSS::Error if channel.nil?
						pubDate_to_dc_date(channel)

						# pre processing
						begin
							rss.output_encoding = charset
						rescue ::RSS::UnknownConvertMethod
						end
						@@mutex.synchronize do 
							@@cache[uri] = {
								:time => Time.now,
								:name => name,
								:channel => channel,
								:items => []
							}
						end

						items = rss.items

						if items.empty?
							@mutex.synchronize do
								@not_include_update_info_resources << [uri, name]
							end
						else
							has_update_info = false

							items.each do |item|
								@@mutex.synchronize do
									pubDate_to_dc_date(item)
									if !has_update_info and (channel.dc_date or item.dc_date)
										has_update_info = true
									end
									@@cache[uri][:items] << item
								end
							end

							unless has_update_info
								@mutex.synchronize do
									@not_include_update_info_resources << [uri, name]
								end
							end

						end

						parsed = true

					end
					
					if !parsed and @@cache[uri][:items].empty?
						@mutex.synchronize do
							@not_include_update_info_resources << [uri, name]
						end
					end

				rescue URI::InvalidURIError
					@mutex.synchronize do
						@invalid_uris << [uri, name]
					end
				rescue InvalidResourceError, ::RSS::Error
					@mutex.synchronize do
						@invalid_resources << [uri, name]
					end
				end
			end

			def parallel_parse(args)
				threads = []
				args.each do |uri, charset, name, expire|
					threads << Thread.new { parse(uri, charset, name, expire) }
				end
				threads.each {|t| t.join}
			end
			
			def recent_changes
				has_update_info_values = []
				used_channel = {}
				@@mutex.synchronize do
					@@cache.each do |uri, v|
						channel = v[:channel]
						next if channel.nil?
						name = v[:name]
						v[:items].each do |item|
							if item.dc_date
								# OK
							elsif channel.dc_date
								next if used_channel.has_key?(channel)
								item.dc_date = channel.dc_date
								used_channel[channel] = nil
							else
								next
							end
							has_update_info_values << [channel, item, name]
						end
					end
				end
				has_update_info_values.sort do |x, y|
					y[1].dc_date <=> x[1].dc_date
				end
			end

			def each
				@@mutex.synchronize do
					@@cache.each do |uri, value|
						next if value[:channel].nil?
						yield(uri, value[:channel], value[:items], value[:name], value[:time])
					end
				end
			end

			def items(uri)
				begin
					@@mutex.synchronize do
						@@cache[uri][:items]
					end
				rescue NameError
					nil
				end
			end

			private
			def fetch_rss(uri)
				rss = ''
				Net::HTTP.start(uri.host, uri.port || 80) do |http|
					path = uri.path
					path << "?#{uri.query}" if uri.query
					req = http.request_get(path, HTTP_HEADER)
					raise InvalidResourceError unless req.code == "200"
					rss << req.body
				end
				rss
			end

			def pubDate_to_dc_date(target)
				if target.respond_to?(:pubDate)
					class << target
						alias_method(:dc_date, :pubDate)
					end
				end
			end
			
		end
		
	end
end
