require "rd/rdvisitor"
require "erb"

class String
	def to_euc
		NKF::nkf( '-m0 -e', self )
	end

	def to_sjis
		NKF::nkf( '-m0 -s', self )
	end

	def to_jis
		NKF::nkf( '-m0 -j', self )
	end
end

module RD
  class RD2TeXPresentationVisitor < RDVisitor
    include MethodParse
		extend ERB::DefMethod

    SYSTEM_NAME = "RWiki -- RD2TeXPresentationVisitor"
    SYSTEM_VERSION = "0.0.1"
    VERSION = Version.new_from_version_string(SYSTEM_NAME, SYSTEM_VERSION)

    def self.version
      VERSION
    end
    
    # must-have constants
    OUTPUT_SUFFIX = "tex"
    INCLUDE_SUFFIX = ["tex"]

		%w(header setting footer).each do |meth|
			def_erb_method(meth, "tex-presentation-#{meth}.rtex")
		end

    def initialize()
      super
    end
    
    def visit(tree)
			super(tree)
    end

    def apply_to_DocumentElement(element, content)
			rv = header()
			display = false
			rv << content.collect do |x|
				if x.kind_of?(Array)
					if x.last
						x = x.last
						display = true
					else
						display = false
					end
				end
				if display
					if x.kind_of?(Proc)
						x.call(0)
					else
						x
					end
				else
					""
				end
			end.join('').to_euc
			rv << footer()
			rv
    end

    def apply_to_Headline(element, title)
			if element.level == 1
				[:headline, <<-EOM]

\\Newslide%---------------------------------------------------------
\\Section{#{title}}
\\Large\\bf

EOM
			else
				[:headline, false]
			end
    end

    # RDVisitor#apply_to_Include 

    def apply_to_TextBlock(element, content)
			"#{content.join('')}\n"
    end

    def apply_to_Verbatim(element)
			%Q[\\begin{alltt}\n#{element.join("\n")}\n\\end{alltt}]
    end

    def apply_to_ItemList(element, items)
			%Q[\\begin{itemize}\n#{items.join("\n").chomp}\n\\end{itemize}]
    end
  
    def apply_to_EnumList(element, items)
			%Q[\\begin{enumerate}\n#{items.join("\n").chomp}\n\\end{enumerate}]
    end
    
    def apply_to_DescList(element, items)
			%Q[\\begin{itemize}\n#{items.join("\n").chomp}\n\\end{itemize}]
    end

    def apply_to_MethodList(element, items)
			%Q[\\begin{itemize}\n#{items.join("\n").chomp}\n\\end{itemize}]
    end
    
    def apply_to_ItemListItem(element, content)
      %Q[\\item #{content.join("\n").chomp}]
    end
    
    def apply_to_EnumListItem(element, content)
      %Q[\\item #{content.join("\n").chomp}]
    end

    def apply_to_DescListItem(element, term, description)
      %Q!\\item[#{term}] #{description.join("\n").chomp}!
    end

    def apply_to_MethodListItem(element, term, description)
      %Q!\\item[#{term}] #{description.join("\n").chomp}!
    end
  
    def apply_to_StringElement(element)
      apply_to_String(element.content)
    end
    
    def apply_to_Emphasis(element, content)
      %Q[{\\em #{content.join("")}}]
    end
  
    def apply_to_Code(element, content)
      %Q[texttt{#{content.join("")}}]
    end
  
    def apply_to_Var(element, content)
      %Q[textit{#{content.join("")}}]
    end
  
    def apply_to_Keyboard(element, content)
      %Q[texttt{#{content.join("")}}]
    end
  
    def apply_to_Index(element, content)
      %Q[content.join('')\\label{#{element.label}}]
    end

		def apply_to_Reference(element, content)
			%Q[content.join('')\\ref{#{element.label}}]
		end

    def apply_to_Reference_with_RDLabel(element, content)
			content.join('')
    end

    def apply_to_Reference_with_RWikiLabel(element, content)
			content.join('')
    end

    def apply_to_Reference_with_URL(element, content)
			"[#{element.label.url} #{content.join('')}]"
    end

    def apply_to_RefToElement(element, content)
			content.join('')
    end

    def apply_to_RefToOtherFile(element, content)
			content.join('')
    end
    
    def apply_to_Footnote(element, content)
      content.join('')
    end

    def apply_to_Foottext(element, content)
      content.join('')
    end
    
    def apply_to_Verb(element)
      content = apply_to_String(element.content)
      "\\verb|#{content}|"
    end

    def apply_to_String(element)
			element
      #meta_char_escape(element)
    end
    
  end # RD2TeXPresentationVisitor
end # RD

$Visitor_Class = RD::RD2TeXPresentationVisitor
