
RWiki::Version.regist('rw-concat', '2002-05-09 cloudy')

class ConcatFormat < RWiki::PageFormat

	LABEL_PREFIX = "concat_"

	def navi_view(pg, title, referer)
		%Q[<a href="#{ref_name(pg.name)};top=#{ref_url(u(referer.name))}">#{ h title }</a>]
	end

	private
	def make_id(name)
		h(u("#{LABEL_PREFIX}#{name}")).gsub(/%/, ".")
	end

  @rhtml = { :view => RWiki::ERbLoader.new('view(pg)', 'concat.rhtml')}
  reload_rhtml
end

RWiki::install_page_module('concat', ConcatFormat, 'Concat')

