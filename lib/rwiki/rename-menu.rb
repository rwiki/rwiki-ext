module RWiki
	class Book

		def rename_menu(substitution_table)
			@navi.each do |title, page|
				if substitution_table.has_key?(title)
					title.replace(substitution_table[title])
				end
			end
		end

	end
end
