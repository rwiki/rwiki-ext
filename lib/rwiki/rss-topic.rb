require "rwiki/rss-page"
require "rwiki/rss-maneger"

module RWiki
	module RSS

		module Topic

			extend ERB::Util

			class << self

				def mutex_attr(id, writable=false)
					module_eval(<<-EOC)
					def self.#{id.id2name}
						@@mutex.synchronize do
							@@#{id.id2name}
						end
					end
					EOC

					mutex_attr_writer(id) if writable
					
				end

				def mutex_attr_writer(*ids)
					ids.each do |id|
						module_eval(<<-EOC)
						def self.#{id.id2name}=(new_value)
							@@mutex.synchronize do
								@@#{id.id2name} = new_value
							end
						end
						EOC
					end
				end

				def mutex_attr_reader(*ids)
					ids.each do |id|
						mutex_attr(id, false)
					end
				end

				def mutex_attr_accessor(*ids)
					ids.each do |id|
						mutex_attr(id, true)
					end
				end

				@@lang = ::RWiki::PageFormat.module_eval('@@lang')
				@@mutex = Mutex.new

				def clear
					@@mutex.synchronize do
						@@maneger = ::RWiki::RSS::Maneger.new
						@@topics = {}
						@@pages = DISPLAY_PAGES
						@@characters = DISPLAY_CHARACTERS
						@@use_thread = false
						@@display = false
						@@expire = ::RWiki::RSS::EXPIRE
					end
				end

				def forget
					::RWiki::RSS::Maneger.forget(expire)
				end

				def add_topic(uri, charset, name)
					@@topics[uri] = [charset, name, expire]
				end

				def each_topics(&block)
					if @@display
						parse
						@@maneger.each(&block)
					else
						[]
					end
				end

				def parse
					forget
					if @@use_thread
						arg = @@topics.collect {|uri, values| [uri, *values]}
						@@maneger.parallel_parse(arg)
					else
						@@topics.each do |uri, values|
							@@maneger.parse(uri, *values)
						end
					end
				end

			end

			mutex_attr_accessor :use_thread, :pages, :characters
			mutex_attr_accessor :display, :expire
			mutex_attr_reader :topics

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
