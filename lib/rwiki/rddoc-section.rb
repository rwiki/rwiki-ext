require "English"

module RD
	class DescListItem
		def content
			@description
		end
	end
end

module RDDoc

	class Reference
		attr_reader :value, :label
		def initialize(value, label=nil)
			@value = value
			@label = label
		end

		def to_s
			@value
		end

	end

	class Definition
		attr_reader :term, :description
		def initialize(term, description)
			@term = term
			@description = description
		end

		def to_s
			@term
		end
	end

	class Section

		attr_reader :name, :enum_list, :item_list, :desc_list, :sections
		attr_reader :enum_list_elements, :item_list_elements, :desc_list_elements
		attr_reader :section, :texts

		def self.new_by_tree(tree)
			children = tree.root.children
			headline = nil
			index = nil
			children.each_with_index do |child, i|
				if child.kind_of?(RD::Headline)
					headline = child
					index = i + 1
					break
				end
			end
			if headline
				new(headline, children[index..-1])
			else
				raise "No Headline found"
			end
		end

		def initialize(headline, children)
			@name = to_string(headline.title).strip
			@sections = []
			@section = {}
			@enum_list = []
			@enum_list_elements = []
			@item_list = []
			@item_list_elements = []
			@desc_list = []
			@desc_list_elements = []
			@texts = []

			parse_children(headline, children)

		end
		
		def each_section(&block)
			@sections.each(&block)
		end
		alias each each_section

		def [](key)
			if key.kind_of?(Numeric)
				@sections[key]
			else
				@section[key]
			end
		end

		def to_rd
		end

		private
		def parse_children(element, children)
# 			p 444
# 			p to_string(element.title)
# 			p children
# 			p 555
			children.each_with_index do |elem, i|
				case elem
				when RD::Headline
					low_level_children, rest =
						split_low_level_children(element.level + 1, children[(i+1)..-1])
# 					p 111
# 					p i
# 					p to_string(elem.title)
# 					p children[(i+1)..-1], low_level_children, rest
# 					p 222
					set_section(elem, low_level_children)
					if rest.first.kind_of?(RD::Headline)
						return parse_children(element, rest)
					end
					break
				when RD::ItemList
					set_list(@item_list, @item_list_elements, elem)
				when RD::EnumList
					set_list(@enum_list, @enum_list_elements, elem)
				when RD::DescList
					set_list(@desc_list, @desc_list_elements, elem)
				when RD::TextBlock
					set_text(elem)
				end
			end
		end

		def split_low_level_children(level, children)
			low_level_children = []
			index = nil

			children.each_with_index do |elem, i|
				case elem
				when RD::Headline
					if elem.level <= level
						index = i
						break
					else
						low_level_children << elem
					end
				else
					low_level_children << elem
				end
			end

			[
				low_level_children,
				if index.nil?
					[]
				else
					children[index..-1]
				end
			]
		end

		def to_string(array)
			array.collect do |e|
				case e
				when RD::Reference
					case e.label
					when RD::Reference::URL
						Reference.new(e.label.url, to_string(e.label.to_reference_content))
					else
						Reference.new(e.to_label)
					end
				when RD::DescListItem
					Definition.new(e.term, to_string(e.description))
				else
					e.to_label
				end
			end.join('')
		end

		def set_section(headline, rest_elements)
			sec = Section.new(headline, rest_elements)
			@sections << sec
			@section[sec.name] ||= sec
		end

		def set_list(text_target, element_target, list)
			list.each_item do |item|
				text_target << item.content.collect do |x|
					element_target << x
					case x
					when RD::TextBlock
						to_string(x.content).strip
					else
						''
					end
				end.join('')
			end
		end

		def set_text(textblock)
			@texts << to_string(textblock.content).strip
		end

	end

end
