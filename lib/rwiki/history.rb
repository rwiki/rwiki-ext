RWiki::Version.regist('rw-history', '2004-02-10')

require "time"

module RWiki

	class Page

		attr_reader(:logs)

		alias __initialize initialize
		def initialize(*args)
			__initialize(*args)
			@logs = db.logs(@name)
		end
		
		alias _set_src set_src
		def set_src(*args, &block)
			_set_src(*args, &block)
			@logs = db.logs(@name)
		end

		def diff(rev1, rev2)
			db.diff(@name, rev1, rev2)
		end

	end

	class PageFormat
		private
		def get_var(name, default='')
			tmp, = var(name)
			tmp || default
		end
	end

	class PageStore
		def logs(target)
			[]
		end

		def diff(target, rev1, rev2)
			nil
		end
	end

	class PageStoreCVS

    def run_cvs(*args)
      STDERR.puts(args.inspect) if PageStoreCVS::Develop
      `#{make_command(@cvs, @cvs_options, '-d', @cvsrepo, *args)}`
    end

		def make_command(*args)
			args.collect {|x| x.dump}.join(" ")
		end

		def cvs_log(filename)
      run_cvs('log', '--', filename)
		end

    def logs(page_name)
			filename = fname(page_name)
			result = []
			log = nil
			cvs_log(filename).each do |line|
				case line
				when /\Arevision ((?:\d+\.)+\d+)\s/
					log = RWiki::Log.new($1)
					result.push(log)
				when /\Adate: /
					if log
						line.split(";").each do |param|
							name, *value = param.split(":")
							unless value.empty?
								value = value.join(":").strip
								if name == "date" and /\s+[+-]\d\d\d\d\z/ !~ value
									# offset is not given
									value << " -0000"
								end
								log.send("#{name.strip}=", value)
							end
						end
					end
				when /\Abranches: /
					# not need
				when /\A(?:-+|=+)$/
					log = nil
				when "*** empty log message ***\n"
					# no log message
				else
					if log
						log.commit_log ||= ""
						log.commit_log << KCode.kconv(line.gsub(/\\(\d\d\d)/) {$1.oct.chr})
					end
				end
			end
			result
		end

		def diff(target, rev1, rev2)
			dif = run_cvs("diff", "-u", "-r", rev1, "-r", rev2, fname(target))
			result = ""
			in_body = false
			dif.each do |line|
				case line
				when /\A(---|\+\+\+)\s*\S+\s*(.*)\s*(?:\d+\.)+\d+\n/
					t = Time.parse($2).localtime
					result << "#{$1} #{t}\n" unless in_body
				when /\A@@/
					in_body = true
				end
				result << line if in_body
			end
			result
		end
	end

	class Log

		attr_accessor :author, :state, :lines, :commit_log
		attr_reader :date, :revision
		
		def initialize(rev)
			@revision = rev
		end
		
		def date=(val)
			if val.kind_of?(Time)
				@date = val
			else
				@date = Time.parse(val)
			end
			@date.localtime
		end

	end

end

module DiffLink
	def diff_link(targ, r1, r2)
		if r1 >= 0 and r2 > 0
			%Q{[<a href="#{diff_href(targ, r1, r2)}">#{r1}&lt;=&gt;#{r2}</a>]}
		end
	end

	def diff_href(targ, r1, r2)
		ref_name("diff", {"target" => targ, "rev1" => r1, "rev2" => r2,})
	end

	def target(default=RWiki::TOP_NAME)
		get_var("target", default)
	end

	def rev1
		get_var("rev1", rev2 - 1).to_i
	end
	
	def rev2
		get_var("rev2", "-1").to_i
	end

end

class HistoryFormat < RWiki::PageFormat
	include DiffLink

  @rhtml = { :view => RWiki::ERbLoader.new('view(pg)', 'history.rhtml')}
  reload_rhtml

  def navi_view(pg, title, referer)
    %Q[<span class="navi">[<a href="#{ ref_name(pg.name, 'target' => target(nil) || referer.name) }">#{ h title }</a>]</span>]
  end
end

class DiffFormat < RWiki::PageFormat
	include DiffLink

  @rhtml = { :view => RWiki::ERbLoader.new('view(pg)', 'diff.rhtml')}
  reload_rhtml

	def diff(pg, log1, log2)
		result = nil
		if log1 and log2
			result = pg.book[target].diff(log1.revision, log2.revision)
			result = nil if /\A\s*\z/ =~ result
		end
		result
	end

  def navi_view(pg, title, referer)
    %Q[<span class="navi">[<a href="#{ ref_name(pg.name, {'target' => target(nil) || referer.name}) }">#{ h title }</a>]</span>]
  end
end

RWiki::install_page_module('history', HistoryFormat, "History")
RWiki::install_page_module('diff', DiffFormat, "Diff")
