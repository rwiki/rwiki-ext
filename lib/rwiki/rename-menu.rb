module RWiki
	class Book

		def rename_menu(substitution_table)
			@navi.each do |title, page|
				if substitution_table.has_key?(title)
					title.replace(substitution_table[title])
				end
			end
			navi_label.each do |key, value|
				if substitution_table.has_key?(key)
					value.replace(substitution_table[key])
				end
			end
		end

		def navi_label
			@navi_label ||= make_navi_label
		end

		private
		def make_navi_label
			{
				'link' => 'Link',
				'src' => 'Src',
				'edit' => 'Edit',
				'slide' => 'Slide',
				'help' => 'Help',
				'search' => 'Search',
			}
		end

	end
end
