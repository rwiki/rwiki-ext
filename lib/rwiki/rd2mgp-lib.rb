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
  class RD2MagickPointVisitor < RDVisitor
    include MethodParse

    SYSTEM_NAME = "RWiki -- RD2MagickPointVisitor"
    SYSTEM_VERSION = "0.0.1"
    VERSION = Version.new_from_version_string(SYSTEM_NAME, SYSTEM_VERSION)

    def self.version
      VERSION
    end
    
    # must-have constants
    OUTPUT_SUFFIX = "mgp"
    INCLUDE_SUFFIX = ["mgp"]

    def initialize()
      super
    end
    
    def visit(tree)
      super(tree)
    end

    def apply_to_DocumentElement(element, content)
      rv = %Q!%include "default.mgp"\n!
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
      end.join('')
      rv.to_jis
    end

    def apply_to_Headline(element, title)
      if element.level == 1
        [:headline, <<-EOM]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%page

#{title}


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
      content = <<-EOT

%filter "./latex2eps.sh -s 5 #{@counter}.eps"
\\begin{alltt}
EOT
      element.each_line do |line|
        content << line#"  #{line}"
      end
      content << <<-EOT
\\end{alltt}
%endfilter
%image "#{@counter}.eps" 800x600
EOT
      @counter += 1
      content
    end

    def make_list_proc(items)
      Proc.new do |depth|
        items.collect do |item|
          item.call(depth + 1)
        end.join
      end
    end
  
    def apply_to_ItemList(element, items)
      make_list_proc(items)
    end
  
    def apply_to_EnumList(element, items)
      make_list_proc(items)
    end
    
    def apply_to_DescList(element, items)
      items.join
    end

    def apply_to_MethodList(element, items)
      "#{items.join('')}"
    end
    
    def make_item_proc(mark, content)
      Proc.new do |depth|
        content.collect do |c|
          if c.kind_of?(Proc)
            c.call(depth)
          else
            "#{mark * depth} #{c}"
          end
        end.join
      end
    end
    private :make_item_proc

    def apply_to_ItemListItem(element, content)
      make_item_proc("\t", content)
    end
    
    def apply_to_EnumListItem(element, content)
      make_item_proc("\t", content)
    end

    def apply_to_DescListItem(element, term, description)
      "\t#{term}\n\t\t#{description.join('')}"
    end

    def apply_to_MethodListItem(element, term, description)
      "\t#{term}\n\t\t#{description.join('')}"
    end
  
    def apply_to_StringElement(element)
      apply_to_String(element.content)
    end
    
    def apply_to_Emphasis(element, content)
      content.join('')
    end
  
    def apply_to_Code(element, content)
      content.join('')
    end
  
    def apply_to_Var(element, content)
      content.join('')
    end
  
    def apply_to_Keyboard(element, content)
      content.join('')
    end
  
    def apply_to_Index(element, content)
      content.join('')
    end

    def apply_to_Reference(element, content)
      content.join('')
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
      "#{content}\n"
    end

    def apply_to_String(element)
      element
      #meta_char_escape(element)
    end
    
  end # RD2MagickPointVisitor
end # RD

$Visitor_Class = RD::RD2MagickPointVisitor
