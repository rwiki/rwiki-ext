require 'rwiki/soap/driver'
require "rwiki/custom-edit"

RWiki::Version.regist('rwiki/soap', '2004-09-06')

module RWiki
  module SOAP

    class << self

      def install
        config = BookConfig.default.dup
        config.page = Custom::EditPage
        config.format = RWiki::SOAP::PageFormat
        sec = RWiki::SOAP::Section.new(config, "soap")
        RWiki::Book.section_list.push(sec)
        RWiki.install_page_module('soap', RWiki::SOAP::PageFormat, 'SOAP')
      end

    end

    class PropLoader
      def load(content)
        doc = Document.new(content.tree)
        prop = doc.to_prop
        prop[:name] = content.name
        prop
      end
    end

    class Document

      def initialize(tree)
        @section = RDDoc::Section.new_by_tree(tree)
      end

      def to_prop
        prop = {}
        if @section
          ep = EntryParser.new(@section["entry"] || @section["エントリー"])
          prop[:entry] = ep.prop
        end
        prop
      end
    end

    class EntryParser
      attr_reader :prop

      def initialize(section = nil)
        @prop = {}
        if section
          section.item_list.each do |item|
            add_entry(item)
          end
        end
      end

      def add_entry(text)
        name, uri = parse(text)
        name = nil if name and name.empty?
        @prop[uri] = name if uri
      end

      private
      def parse(str)
        if str
          str.split(":", 2).collect {|x| x.strip}
        else
          [nil, nil]
        end
      end

    end

    class Section < Custom::EditSection

      def initialize(config, pattern)
        super(config, pattern)
        add_prop_loader(:soap, PropLoader.new)
        add_default_src_proc(method(:default_src))
      end

      RWiki::ERbLoader.new('default_src(name)', 'soap/src.erd').load(self)

    end

    class PageFormat < Custom::EditFormat
      @rhtml = { :view => RWiki::ERbLoader.new('view(pg)', 'soap/view.rhtml') }
      reload_rhtml
    end

  end

end

RWiki::SOAP.install
