module RWiki
  module Custom

    module EditUtils
      def section(pg, name=pg.name)
        prop = pg.book[name].prop(:edit) || {}
        prop[:section]
      end
    end

    module Type

      class String
        
        def initialize(string)
          @string = string
        end
        
        def to_html(format, pg)
          @string
        end

      end
      

      class StringFormat < EditFormat
        
        extend EditUtils
        
        def self.create_type(pg, name, i=nil)
          String.new(get_value(pg, name, i) || "")
        end
        
        def self.get_value(pg, name=pg.name, i=nil)
          sec = section(pg, name)
          if sec
            sec.texts[i || 0]
          else
            nil
          end
        end
        
        def self.create_rd_writer(pg, name, &var)
          RDWriter.new(nil, nil) do |key|
            var[key]
          end
        end
        
        def create_src(pg, src)
          RDWriter.new(pg.name, "field") do |key|
            if key == "field"
              get_var("field")
            else
              get_var(key)
            end
          end.to_rd(0, pg)
        end

        private
        def get_value(pg)
          self.class.get_value(pg, pg.name)
        end

        def make_fields(pg)
          [Textarea.new("field", get_value(pg))]
        end
      end

      class List

        def initialize(columns, default_column=[], additional_columns=0)
          @columns = columns
          @default_column = default_column
          @additional_columns = additional_columns
        end

        def to_html(format, pg)
          rv = @columns.collect do |column|
            column.to_html(format, pg)
          end.join("<br />\n"). concat("<br />\n")
          @additional_columns.times do
            rv << @default_column.collect do |column|
              column.to_html(format, pg)
            end.join("").concat("<br />\n")
          end
          rv
        end

      end

      class Component
        
        def initialize(components)
          @components = components
        end

        def to_html(format, pg)
          @components.collect do |component|
            component.to_html(format, pg)
          end.join("")
        end

      end

      class Text

        def initialize(name, value)
          @name = name
          @value = value
        end

        def to_html(format, pg)
          %Q!<input type="text" name="#{format.h @name}" value="#{format.h @value}" #{format.tabindex} />\n!
        end

      end

      class TextFormat < EditFormat

        extend EditUtils

        def self.create_type(pg, name, i=nil)
          value = nil
          sec = section(pg)
          p 10
          p sec
          p name
          p sec[name]
          if sec and sec[name]
            p 5
            value ||= sec[name].item_list[i || 0]
          end
          value ||= get_value(pg, name)
          Text.new(name, value || "")
        end

        def self.get_value(pg, name=pg.name)
          sec = section(pg, name)
          if sec
            sec.texts.first
          else
            nil
          end
        end

        def self.create_rd_writer(pg, name, &var)
          RDWriter.new(name, name) do |key|
            if key == name
              var[key].find_all {|x| x !~ /\A\s*\z/}
            else
              var[key]
            end
          end
        end

        def create_src(pg, src)
          RDWriter.new(pg.name, "field").to_rd(0, pg) do |key|
            if key == "field"
              get_var("field")
            else
              get_var(key)
            end
          end
        end

        private
        def get_value(pg)
          self.class.get_value(pg, pg.name)
        end

        def make_fields(pg)
          [Text.new("field", get_value(pg))]
        end
      end

      class Textarea

        def initialize(name, value)
          @name = name
          @value = value
        end

        def to_html(format, pg)
          %Q!<textarea name="#{format.h @name}" #{format.tabindex}>#{format.h @value}</textarea>!
        end

      end

      class TextareaFormat < EditFormat

        def self.create_type(pg, name, i=nil)
          type = fields(pg, name)[:type]
          if type and type.item_list.first
            Textarea.new(type.item_list[i || 0])
          else
            nil
          end
        end

      end

      class Select

        def initialize(name, options, multiple=false)
          @name = name
          @options = options
          @multiple = multiple ? 'multiple="true"' : ''
        end

        def to_html(format, pg)
          rv = %Q!<select name="#{format.h @name}" #{@multiple} #{format.tabindex}>\n!
          @options.each do |option|
            rv << option.to_html(format, pg)
          end
          rv << %Q!</select>\n!
          rv
        end

      end

      class SelectFormat < EditFormat

        def self.create_type(pg, name)
          type = fields(pg, name)[:type]
          options = []
          if type
            type.item_list.each do |item|
              options << Option.new(*item.split(":", 2))
            end
          end
          Select.new(name, options, false)
        end

      end

      class MultipleSelect < Select

        def initialize(name, options)
          super(name, option, true)
        end

      end

      class MultipleSelectFormat < EditFormat

        def self.create_type(pg, name)
          type = fields(pg, name)[:type]
          options = []
          if type
            type.item_list.each do |item|
              options << Option.new(*item.split(":", 2))
            end
          end
          MultipleSelect.new(name, options)
        end

      end

      class Option
        
        def initialize(value, label=value, selected=false)
          @value = value
          @label = label
          @selected = selected ? 'selected="true"' : ''
        end

        def to_html(format, pg)
          %Q!<option value="#{format.h @value}" #{@selected}>#{format.h @label}</option>\n!
        end

      end

      class Optgroup

        def initialize(label, options)
          @label = label
          @options = options
        end
        
        def to_html(format, pg)
          rv = %Q!<optgroup label="#{format.h @label}">\n!
          @options.each do |option|
            rv << option.to_html(format, pg)
          end
          rv << %Q!</optgroup>\n!
          rv
        end

      end

      class Checkbox

        def initialize(name, value, label=value, checked=false)
          @name = name
          @value = value
          @label = label
          @checked = checked ? 'checked="true"' : ''
        end

        def to_html(format, pg)
          %Q!<input type="checkbox" name="#{format.h @name}" ! <<
            %Q!value="#{format.h @value}" #{format.tabindex} ! <<
            %Q!#{@checked} #{format.h @label}\n!
        end

      end

      class CheckboxFormat < EditFormat

        def self.create_type(pg, name)
          type = fields(pg, name)[:type]
          checkboxes = []
          if type
            type.item_list.each do |item|
              checkboxes << Checkbox.new(name, *item.split(":", 3))
            end
          end
          Component.new(checkboxes)
        end

      end

      class Radio

        def initialize(name, value, label=value, checked=true)
          @name = name
          @value = value
          @label = label
          @checked = checked ? 'checked="true"' : ''
        end

        def to_html(format, pg)
          %Q!<input type="radio" name="#{format.h @name}" ! <<
            %Q!value="#{format.h @value}" #{format.tabindex} ! <<
            %Q!#{@checked} #{format.h @label}\n!
        end

      end

      class RadioFormat < EditFormat

        def self.create_type(pg, name)
          type = fields(pg, name)[:type]
          radios = []
          if type
            type.item_list.each do |item|
              radios << Radio.new(name, *item.split(":", 3))
            end
          end
          Component.new(radios)
        end

      end

    end
  end
end
