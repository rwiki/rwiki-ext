require "uri"

require "rwiki/rddoc"
require "rwiki/custom-edit"

RWiki::Version.regist('ImportWiki', '2003-07-10')

module RWiki
  module ImportWiki

    @@wiki = {}

    class Error < RWikiError; end
    class InvalidResourceError < Error; end
    
    class << self

      def install
        config = ::RWiki::BookConfig.default.dup
        config.format = AdminPageFormat
        config.page = ::RWiki::Custom::EditPage
        sec = Section.new(config, 'ImportWiki')
        ::RWiki::Book.section_list.push(sec)
      end

      def install_wiki(wiki_type, connector)
        @@wiki[wiki_type] = {}
        config = ::RWiki::BookConfig.default.dup
        config = make_import_section_config(config, connector, wiki_type)
        sec = ImportSection.new(config, /\A#{wiki_type}:[^:]+:/, connector, wiki_type)
        ::RWiki::Book.section_list.push(sec)
      end

      def initialize_pages

        import_pages = []
        ObjectSpace.each_object(::RWiki::ImportWiki::ImportPage) do |o|
          if o.name == "ImportWiki"
            o._src = o.section.db[o.name] || o.section.default_src(o.name)
          else
            import_pages << o
          end
        end
        import_pages.each do |page|
          begin
            page._src = page.section.db[page.name] || page.section.default_src(page.name)
          rescue Error
          end
        end

      end

      def has_type?(wiki_type)
        @@wiki.has_key?(wiki_type)
      end

      def [](wiki_type)
        @@wiki[wiki_type]
      end

      def clear
        @@wiki.each do |wiki_type, wiki|
          wiki.clear
        end
      end

      def each_wiki_type(&block)
        @@wiki.each_key(&block)
      end

      def each
        @@wiki.each do |wiki_type, wiki_info|
          wiki_info.each do |name, encoding, source_uri|
            yield(wiki_type, name, encoding, source_uri)
          end
        end
      end

      @@available_encodings = %w(euc-jp Shift_JIS UTF-8 ISO-2022-JP)
      def available_encodings
        @@available_encodings
      end

      private

      def make_import_section_config(config, connector, wiki_type)
        config.db = PageCacheFile.new(DB_DIR, connector, wiki_type)
        config.page = ImportPage
        config.format = ImportPageFormat
        config
      end
        
    end

    class PropLoader
      def load(content)
        doc = Document.new(content.tree)
        prop = doc.to_prop
        prop[:name] = content.name
        ImportWiki.clear
        if prop[:entry]
          prop[:entry].each do |wiki_type, info|
            if wt = ImportWiki[wiki_type]
              info.each do |wiki_name, wiki_info|
                wt[wiki_name] = wiki_info
              end
            end
          end
        end
        prop
      end
    end

    class Document < RDDoc::SectionDocument
      def to_prop
        prop = {}
        each_section do |head, content|
          next unless head
          if head.level == 2
            case title = as_str(head.title).strip.downcase
            when 'entry', 'エントリー'
              EntrySection.new(prop).apply_Section(content)
            end
          end
        end
        prop
      end
    end

    class PropSection < RDDoc::PropSection
      def apply_Item(str)
        if /^([^:]*):\s*([^:]*):\s*([^:]*):\s*(.*)$/ =~ str
          apply_Prop($1.strip, $2.strip, $3.strip, $4.strip)
        end
      end
    end

    class EntrySection < PropSection
      def apply_Prop(wiki_type, wiki_name, encoding, source_uri)
        @prop[:entry] ||= {wiki_type => {}}
        @prop[:entry][wiki_type] ||= {}
        @prop[:entry][wiki_type][wiki_name] = [encoding, source_uri]
      end
    end

    class PageCacheFile < ::RWiki::DB::Base
      include MonitorMixin

      EXPIRE = 30 * 60

      def initialize(path, connector_class, wiki_type)
        @dir = path.split(File::Separator)
        @connector_class = connector_class
        @connector_cache = {}
        @wiki_type = wiki_type
        @recache_table = {}
        super()
      end

      def each
        Dir[File.join(@dir + ['*.cache'])].collect do |filename|
          yield(unescape(File.basename(filename, '.cache')))
        end
      end

      def modified(name)
        wiki_name, page_name = split_name(name)
        begin
          if_old_then_cache(name, wiki_name, page_name)
          connector(wiki_name).modified(page_name)
        rescue NameError
          nil
        end
      end

      def revision(name)
        wiki_name, page_name = split_name(name)
        begin
          if_old_then_cache(name, wiki_name, page_name)
          connector(wiki_name).revision(page_name)
        rescue NameError
          ''
        end
      end
      
      def recached?(name)
        @recache_table[name]
      end

      def []=(*arg)
        k = arg.shift
        v = arg.pop
        rev = arg.shift
        opt = {
          :query => arg.shift,
          :revision => rev,
        }
        # check_revision(k, rev)
        set(k, store(v), opt)
      end

      private
      def set(name, src, opt=nil)
        return if src.nil?
        wiki_name, page_name = split_name(name)
        begin
          query = opt[:query]
          if query
            commit_message = query['commit_log'].to_s
          else
            commit_message = ''
          end
          connector(wiki_name).submit(page_name, src, commit_message)
          cache(name, src, false)
        rescue NameError
          nil
        end
      end

      def get(name)
        wiki_name, page_name = split_name(name)
        begin
          cache(name, connector(wiki_name).fetch(page_name), false)
          read_cache(name)
        rescue Error, NameError
          nil
        end
      end

      def cache(name, src, recache=true)
        synchronize do
          unless src.nil?
#           p "This is recache? #{recache}"
            @recache_table[name] = recache
#           p "Writing cache of #{fname(name)}. src is #{src}"
            File.open(fname(name), 'w') {|fp| fp.write(src)}
          end
        end
      end

      def read_cache(name)
        synchronize do
#         p "Reading cache of #{fname(name)}"
          File.open(fname(name)) {|fp| fp.read} rescue nil
        end
      end

      def if_old_then_cache(name, wiki_name, page_name)
        begin
          stat = File.stat(fname(name))
#         p "Comparing cache time #{stat.mtime} ... "
#         p "recache? #{stat.mtime + EXPIRE < Time.now}"
          raise if stat.mtime + EXPIRE < Time.now
        rescue
          begin
            cache(name, connector(wiki_name).fetch(page_name))
          rescue Error, NameError
#           p "Error occured in caching"
#           p $!
#           puts $@ 
          end
        end
      end

      def connector(name)
        unless @connector_cache.has_key?(name)
          begin
            encoding, source_uri = ImportWiki[@wiki_type][name]
            uri = URI.parse(source_uri)
            @connector_cache[name] = @connector_class.new(uri, encoding)
          rescue URI::InvalidURIError
          end
        end
        @connector_cache[name]
      end

      def escape(str)
        str.gsub(/([^a-zA-Z0-9_-])/n){ sprintf("%%%02X", $1.unpack("C")[0]) }
      end
      
      def unescape(str)
        str.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n) do
          [$1.delete('%')].pack('H*')
        end
      end

      def fname(k)
        File.join(*(@dir + ["#{escape(k)}.cache"]))
      end

      def split_name(name)
        name =~ /\A#{@wiki_type}:([^:]+):(.+)/
        [$1, $2]
      end
      
    end

    class ImportPage < ::RWiki::Page

      def _src=(src)
        update_src(src)
      end

      def src
        reload_src
        @src
      end

      def reload_src(force=false)
#       puts caller[0..3]
#       p "Force reload? #{force}"
#       p "Need reload? #{@section.db.recached?(@name)}"
        if force or @section.db.recached?(@name)
#         p "RELOAD!!!!!!!!!!"
          update_src(@section.db[name])
        end
      end

    end

    class ImportSection < ::RWiki::Section

      def initialize(config, pattern, connector, wiki_type)
        super(config, pattern)
        add_prop_loader(:import_wiki, PropLoader.new)
        @connector = connector
      end

    end

    class Section < ::RWiki::Section

      def initialize(config, string)
        super(config, string)
        add_prop_loader(:import_wiki, PropLoader.new)
        add_default_src_proc(method(:default_src))
      end

      ::RWiki::ERbLoader.new('default_src(name)', 'importwiki.erd').load(self)

    end

    class AdminPageFormat < ::RWiki::PageFormat
      @rhtml =
        {
          :view => ERbLoader.new('view(pg)', 'importwiki.rhtml'),
      }
      reload_rhtml


      def create_src(pg, src)
        rv = pg.src
        wiki_type, = var('wiki_type')
        encoding, = var('encoding')
        wiki_name, = var('wiki_name')
        source_uri, = var('source_uri')
        if !wiki_type.to_s.empty? and
            !encoding.to_s.empty? and
            !wiki_name.to_s.empty? and
            !source_uri.to_s.empty?
          begin
            URI.parse(source_uri)
            rv += "\n* #{wiki_type} : #{wiki_name} : #{encoding} : #{source_uri}"
          rescue URI::InvalidURIError
          end
        elsif !src.to_s.empty?
          rv = src
        end
        rv
      end

    end

    class ImportPageFormat < ::RWiki::PageFormat
      def edit(pg)
        pg.reload_src(true)
        super
      end
    end

    class BaseConnector
      
      @@charset = CHARSET || KCode.charset

      class DummyConverter

        def convert(value)
          value
        end

      end

      @@dummy_converter = DummyConverter.new

      def initialize(uri, encoding)
        @uri = uri
        begin
          require "rss/converter"
          begin
            @converter = ::RSS::Converter.new(encoding, @@charset)
          rescue ::RSS::UnknownConvertMethod
            @converter = @@dummy_converter
          end
        rescue LoadError
          @converter = @@dummy_converter
        end
      end

      private
      def page_name(name)
        escape(@converter.convert(name))
      end

      def escape(str)
        str.gsub(/([^a-zA-Z0-9_-])/n){ sprintf("%%%02X", $1.unpack("C")[0]) }
      end
      
      def unescape(str)
        str.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n) do
          [$1.delete('%')].pack('H*')
        end
      end

    end

  end

  install_page_module('ImportWiki', ::RWiki::ImportWiki::AdminPageFormat, 'ImportWiki')

end

::RWiki::ImportWiki.install

