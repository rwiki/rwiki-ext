module RWiki

	module PreSet

		class PageStore < RWiki::BookConfig.default.db.class
			def store(string)
				string.gsub!(/<%=\s*(\S*)\s*%>/m) do |s|
					case $1
					when 'date'
						Time.now.strftime("%Y-%m-%d")
					when 'time'
						Time.now.strftime("%Y-%m-%d %H:%M:%S(%Z)")
					else
						s
					end
				end
# 				string.gsub!(/「([^\s」]{1,20})」/m) do |s|
# 					if !$1.include?('))')
# 						"「((<#{$1}>))」"
# 					else
# 						s
# 					end
# 				end
				super(string)
			end

		end

	end

	BookConfig.default.db = RWiki::PreSet::PageStore.new(DB_DIR)

end
