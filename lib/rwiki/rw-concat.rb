
RWiki::Version.regist('rw-concat', '2003-08-04 cloudy')

class ConcatFormat < RWiki::PageFormat

	LABEL_PREFIX = "concat_"

	def navi_view(pg, title, referer)
		%Q[<span class="navi"><a href="#{ref_name(pg.name, 'top' => ref_url(u(referer.name)))}">#{ h title }</a></span>]
	end

	private
	def make_id(name)
		h(u("#{LABEL_PREFIX}#{name}")).gsub(/%/, ".")
	end

  @rhtml = { :view => RWiki::ERbLoader.new('view(pg)', 'concat.rhtml')}
  reload_rhtml
end

RWiki::install_page_module('concat', ConcatFormat, 'Concat')

