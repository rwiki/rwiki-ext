require "English"
require "erb"

require "rd/rdvisitor"

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
			found = false
			rtex_name = "tex-presentation-#{meth}.rtex"
			$LOAD_PATH.each do |x|
				['rwiki', ''].each do |sub|
					fname = File.join(x, sub, rtex_name)
					if File.exist?(fname)
						def_erb_method(meth, fname)
						found = true
					end
				end
				break if found
			end
			raise "template file #{rtex_name} doesn't found." unless found
		end

    def initialize()
      super
			@first_headline = true
			@second_headline = false
			@previous_title = nil
			@indent = 1
			@info = {}
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
				text = ""
				if @first_headline
					@info["title"] = title
					@first_headline = false
					@second_headline = true
					[:headline, false]
				else
					if @second_headline
						@second_headline = false
					else
						text << %Q[\t\\end{slide}\n]
					end
					text << %Q[\n\t\\begin{slide}{#{title}}\n]
					@previous_title = title
					[:headline, text]
				end
			else
				[:headline, false]
			end
    end

    # RDVisitor#apply_to_Include 

    def apply_to_TextBlock(element, content)
			"#{content.join('')}\n"
    end

    def apply_to_Verbatim(element)
			indent do
				contents = []
				element.each_line do |x|
					contents.push(x)
				end
				[%Q[\\begin{alltt}],
					contents.collect{|x| x.chomp},
				 %Q[\\end{alltt}\n]].flatten
			end
    end

    def apply_to_ItemList(element, items)
			if in_first_slide
				""
			else
				indent do
					[%Q[\\begin{itemize}],
					 items.collect{|x| x.chomp},
					 %Q[\\end{itemize}\n]].flatten
				end
			end
    end
  
    def apply_to_EnumList(element, items)
			indent do
				[%Q[\\begin{enumerate}],
				 items.collect{|x| x.chomp},
				 %Q[\\end{enumerate}\n]].flatten
			end
    end
    
    def apply_to_DescList(element, items)
			indent do
				[%Q[\\begin{description}],
				 items.collect{|x| x.chomp},
				 %Q[\\end{description}\n]].flatten
			end
    end

    def apply_to_MethodList(element, items)
			indent do
				[%Q[\\begin{itemize}],
				 items.collect{|x| x.chomp},
				 %Q[\\end{itemize}\n]].flatten
			end
    end
    
    def apply_to_ItemListItem(element, content)
			if in_first_slide
				if /\A(\S+)\s*:\s*(.+)/ =~ content.join("\n").chomp
					@info[$1] = $2
				end
				""
			else
				indent do
					%Q[\\item #{content.join("\n").chomp}]
				end
			end
    end
    
    def apply_to_EnumListItem(element, content)
			indent do
				%Q[\\item #{content.join("\n").chomp}]
			end
    end

    def apply_to_DescListItem(element, term, description)
			if in_first_slide
				@info[term] = description.join("").chomp
			else
				indent do
					%Q[\\item[#{term}] #{description.join("\n").chomp}]
				end
			end
    end

    def apply_to_MethodListItem(element, term, description)
			indent do
				%Q[\\item[#{term}] #{description.join("\n").chomp}]
			end
    end
  
    def apply_to_StringElement(element)
      apply_to_String(element.content)
    end
    
    def apply_to_Emphasis(element, content)
      %Q[\\emph{#{content.join("")}}]
    end
  
    def apply_to_Code(element, content)
      %Q[\\texttt{#{content.join("")}}]
    end
  
    def apply_to_Var(element, content)
      %Q[\\textit{#{content.join("")}}]
    end
  
    def apply_to_Keyboard(element, content)
      %Q[\\texttt{#{content.join("")}}]
    end
  
    def apply_to_Index(element, content)
      %Q[\\hypertarget{#{element.label}}{content.join('')}]
    end

		def apply_to_Reference(element, content)
			%Q[\\hyperlink{#{element.label}}{content.join('')}]
		end

    def apply_to_Reference_with_RDLabel(element, content)
			label = content.join('')
			if /\Aimg:/ =~ label
				filename = $POSTMATCH.gsub(/\.[^.]+\z/, '.eps')
				"\\includegraphics[width=1.0\\slideWidth]{#{filename}}"
			else
				label
			end
    end

    def apply_to_Reference_with_URL(element, content)
			label = content.join("")
			label = element.label.url if /\A<URL:/ =~ label
			%Q[\\href{#{element.label.url}}{#{label.gsub(/~/, '\~{}')}}]
    end

    def apply_to_RefToElement(element, content)
			%Q[\\hyperlink{#{element.label}}{content.join('')}]
    end

    def apply_to_RefToOtherFile(element, content)
			content.join('')
    end
    
    def apply_to_Footnote(element, content)
      %Q[\\footnote{#{content.join('')}}]
    end

    def apply_to_Foottext(element, content)
      content.join('')
    end
    
    def apply_to_Verb(element)
      content = apply_to_String(element.content)
      # "\\verb|#{content}|"
    end

    def apply_to_String(element)
			element
      #meta_char_escape(element)
    end

		private
		def indent
			@indent += 1
			ret = yield
			if ret.kind_of?(Array)
				result = ret.collect {|x| %Q[#{"\t" * @indent}#{x}]}.join("\n")
			else
				result = %Q[#{"\t" * @indent}#{ret}]
			end
			@indent -= 1
			result
		end

		def in_first_slide
			!@first_headline and @second_headline
		end
    
  end # RD2TeXPresentationVisitor
end # RD

$Visitor_Class = RD::RD2TeXPresentationVisitor
