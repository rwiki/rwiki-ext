# cgiapp.rb -- based on rw-cgi.rb
#
# Copyright (c) 2000-2003 Masatoshi SEKI and NAKAMURA, Hiroshi
#
# rw-cgi.rb is copyrighted free software by Masatoshi SEKI and NAKAMURA, Hiroshi.
# You can redistribute it and/or modify it under the same terms as Ruby.


###
# SYNOPSIS
#   CGIApp.new( appName )
#
# ARGS
#   appName     Name String of the CGI application.
#
# DESCRIPTION
#   Running this application object as a CGI with 'cmd=[value]' causes
#   executing the method 'exec_proc_[method]_[value]'.
#     ie. POST to 'cmd=entry' -> exec_proc_post_entry
#     ie. HEAD to 'cmd=view' -> exec_proc_head_view
#   Without 'cmd=[value]' in query, 'exec_proc_default' are called.
#
require 'devel/logger'
require 'cgi'
require 'time'
class CGIApp < Devel::Application
  include Devel::Logger::Severity

  public

  def initialize( appName )
    super( appName )
    @cgi = CGI.new()
    @query = @cgi.params
    @cookies = @cgi.cookies
    @os = @cgi
  end

  private

  def run
    prologue()

    log( SEV_INFO, "CGIApp#run: Accessed user '" <<
      ( @cgi.remote_user || 'anonymous' ) << '@' <<
      ( @cgi.remote_host || @cgi.remote_addr || 'unknown' ) << "'." )
    log( SEV_DEBUG, "The query invoked with: #{ @cgi.inspect }." )

    begin
      response = nil
      if ( @query.has_key?( 'cmd' ))
	msg = "exec_proc_#{ @cgi.request_method.to_s.downcase }_#{ @query[ 'cmd' ][0] }"
	if self.respond_to?( msg, true )
	  response = send( msg.intern )
	end
      end

      unless response
	msg = "exec_proc_#{ @cgi.request_method.to_s.downcase }"
	if self.respond_to?( msg, true )
	  response = send( msg.intern )
	end
      end

      unless response
	response = exec_proc_default
      end

      str = response.dump(@cgi)
      log( SEV_DEBUG, "Response:\n#{ str }" )
      print str
    rescue Errno::ECONNREFUSED, DRb::DRbConnError
      errMessage = 'RWiki server seems to be down...'
      log( SEV_DEBUG, "Response:\n#{ response }" )
      print Response.new( Response::Header.new( 503 ), Response::Body.new( errMessage )).dump(@cgi)
      raise
    rescue
      errMessage = 'CGI exec failed.'
      log( SEV_DEBUG, "Response:\n#{ response }" )
      print Response.new( Response::Header.new( 500 ), Response::Body.new( errMessage )).dump(@cgi)
      raise
    end

    epilogue()

    return 0
  end

  def prologue; end
  def epilogue; end

  class Response

    public

    class Header
      attr_accessor :status, :bodyType, :bodyCharset, :bodySize, :bodyDate

      CRLF = "\r\n"

      StatusMap = {
	200 => 'OK',
	302 => 'Object moved',
	304 => 'Not Modified',
	400 => 'Bad Request',
	500 => 'Internal Server Error',
	503 => 'Service Unavailable'
      }

      CharsetMap = {
	'NONE' => 'us-ascii',
	'EUC' => 'euc-jp',
	'SJIS' => 'shift_jis',
      }

      def initialize( status = 200, content_type = 'text/html' )
	@status = status
				@content_type = content_type
	@bodyType = nil
	@bodyCharset = nil
	@bodySize = nil
	@bodyDate = nil
	@extra = []
      end

      def add( key, value )
	@extra.push( [ key, value ] )
      end

      def dump(cgi)
	hash = {}

	str = ''
	if !StatusMap.include?( @status )
	  @status = 400
	end

	hash['status'] = to_cgi_status(@status)

	if @bodySize
	  hash['length'] = @bodySize
	  hash['type'] = @content_type
	  hash['charset'] = CharsetMap[@bodyCharset || $KCODE]
	else
	  hash['connection'] = 'close'
	end
	hash['Last-Modified'] = httpDate(@bodyDate) if @bodyDate

	@extra.each do | key, value |
	  hash[key] = value
	end

	cgi.header(hash)
      end

      private

      def to_cgi_status(number)
	pattern = Regexp.new("^#{number} ")
	CGI::HTTP_STATUS.each do |key, value|
	  return key if pattern =~ value
	end
	return "BAD_REQUEST"
      end

      def dumpItem( str )
	str + CRLF
      end

      def httpDate( aTime )
	aTime.gmtime.strftime( "%a, %d %b %Y %H:%M:%S GMT" )
      end
    end

    class Body
      attr_accessor :type, :charset, :date

      def initialize( body = nil, date = nil, type = nil, charset = nil )
	@body = body
	@type = type
	@charset = charset
	@date = date
      end

      def size
	if @body
	  @body.size
	else
	  nil
	end
      end

      def dump
	@body
      end
    end

    def initialize( header = nil, body = nil )
      self.header = header
      self.body = body
    end

    def dump(cgi)
      unless header
	raise RuntimeError.new( "Response header not set." )
      end
      str = header.dump(cgi)
      str << body.dump if body and body.dump
      str
    end

    def header
      @header
    end

    def header=( header )
      @header = header
      sync
    end

    def body
      @body
    end

    def body=( body )
      @body = body
      sync
    end

    private

    def sync
      if @header and @body
	@header.bodyType = body.type
	@header.bodyCharset = body.charset
	@header.bodySize = body.size
	@header.bodyDate = body.date
      end
    end
  end
end


###
# SYNOPSIS
#   RWikiCGIApp.new( rwiki )
#
# ARGS
#   rwiki     DRb::DRbObject of RWiki server.
#
# DESCRIPTION
#   RWiki CGI interface.
#
require 'drb/drb'
require 'rwiki/rw-lib'

RWiki::Request::COMMAND << 'rss'

class RWikiCGIApp < CGIApp
  include Devel::Logger::Severity

  VERSION = ['rw-cgi', '2.0 ext']

  public

  def initialize( rwiki , logdir )
    super( AppName )
    @rwiki = rwiki
    setLog( File::join( logdir, AppName + '.log' ), 'weekly' )
  end

  private

  AppName = 'RWikiCGIApp'

  def prologue
		@log.sevThreshold = SEV_INFO
  end

  def exec_proc_head_view
    begin
      req = parseRequest()
      raise RWiki::InvalidRequest unless req.name
      page = @rwiki.page( req.name )
      Response.new( Response::Header.new(), Response::Body.new())
    rescue RWiki::InvalidRequest
      requestError
    rescue
      unknownError( $!, $@ )
    end
  end

  def exec_proc_get_view
    begin
      req = parseRequest()
      raise RWiki::InvalidRequest unless req.name
      page = @rwiki.page( req.name )
      header = Response::Header.new()
      if page.empty?
	res = page.edit_html( getEnv ) { |key| @query[key] }
	header.add( 'Cache-Control', 'private' )
      elsif @query.has_key?( 'em' )
	res = page.emphatic_html( getEnv ) { |key| @query[key] }
      else
	res = page.view_html( getEnv ) { |key| @query[key] }
      end
      Response.new( header, Response::Body.new( res ))
    rescue RWiki::InvalidRequest
      requestError
    rescue RWiki::RevisionError
      revisionError( req )
    rescue
      unknownError( $!, $@ )
    end
  end

  def exec_proc_get_edit
    begin
      req = parseRequest()
      page = @rwiki.page( req.name )
      header = Response::Header.new()
      header.add( 'Cache-Control', 'private' )
      res = page.edit_html( getEnv ) { |key| @query[key] }
      Response.new( header, Response::Body.new( res ))
    rescue RWiki::InvalidRequest
      requestError
    rescue
      unknownError( $!, $@ )
    end
  end

  def not_modified_since?(modified)
    return false if modified.nil?
    return false unless ENV.key?('HTTP_IF_MODIFIED_SINCE')
    return modified <= Time.parse(ENV['HTTP_IF_MODIFIED_SINCE'])
  end

  def exec_proc_head_src
    begin
      req = parseRequest()
      raise RWiki::InvalidRequest unless req.name
      modified = @rwiki.page( req.name ).modified
			if not_modified_since?(modified)
				return Response.new( Response::Header.new( 304 ) )
      end
      Response.new( Response::Header.new(), Response::Body.new( nil, modified ))
    rescue RWiki::InvalidRequest
      requestError
    rescue
      unknownError( $!, $@ )
    end
  end

  def exec_proc_get_src
    begin
      req = parseRequest()
      raise RWiki::InvalidRequest unless req.name
      page = @rwiki.page( req.name )
      modified = page.modified
      if not_modified_since?(modified)
        return Response.new( Response::Header.new( 304 ) )
      end
      res = @rwiki.src_view( req.name, getEnv )
      Response.new( Response::Header.new(), Response::Body.new( res, modified ))
    rescue RWiki::InvalidRequest
      requestError
    rescue
      unknownError( $!, $@ )
    end
  end

  def exec_proc_get_rss
    begin
      req = parseRequest()
      raise RWiki::InvalidRequest unless req.name
      page = @rwiki.page( req.name )
      header = Response::Header.new(200, 'application/xml')
			res = page.view_html( getEnv )
      Response.new( header, Response::Body.new( res ))
    rescue RWiki::InvalidRequest
      requestError
    rescue
      unknownError( $!, $@ )
    end
  end

  def exec_proc_post_submit
    begin
      req = parseRequest()
      raise RWiki::InvalidRequest unless req.name
      raise RWiki::InvalidRequest unless req.src
      page = @rwiki.page( req.name )
      page.set_src( req.src, req.rev ) { |key| @query[key] }
      header = Response::Header.new()
			res = page.submit_html( getEnv ) { |key| @query[key] }
      Response.new( header, Response::Body.new( res ))
    rescue RWiki::InvalidRequest
      requestError
    rescue RWiki::RevisionError
      revisionError( req )
    rescue
      unknownError( $!, $@ )
    end
  end

  alias exec_proc_default exec_proc_get_view

  def revisionError( req )
    errMessage =<<__EOM__
Source revision mismatch.

Page '#{ req.name }' has changed since editing started.
Back to the edit page and press 'RELOAD' to refresh the page,
then retry to merge/add your changes to its latest source.

Submitted source:
#{ req.src }
__EOM__
    errorResponse( req.name, errMessage )
  end

  def requestError
    redirectTo = @rwiki.default_url( ENV )
    log( SEV_INFO, "Redirect to '#{ redirectTo }'." )
    header = Response::Header.new( 302 )
    header.add( 'Location', redirectTo )
    Response.new( header )
  end

  def unknownError( err, info )
    errMessage = "#{ err }\n\n" << info.join( "\n" )
    errorResponse( 'error', errMessage )
  end

  def errorResponse( name, msg )
    name = 'error' unless name
    res = @rwiki.error_view( name, getEnv ) { |key|
	case key
	when 'message'
	  msg
	else
	  ''
	end
      }
    Response.new( Response::Header.new( 500 ), Response::Body.new( res ))
  end

  def parseRequest
    log( SEV_DEBUG, "REQUEST_URI: #{ ENV[ 'REQUEST_URI' ] }" )
    log( SEV_DEBUG, "SCRIPT_NAME: #{ ENV[ 'SCRIPT_NAME' ] }" )
    req = RWiki::Request.parse( @query )
    log( SEV_INFO,  "Request: #{ req.inspect }" )
    req
  end

  def getEnv
    server_port = ENV['SERVER_PORT'] || '80'
    server_name = ENV['SERVER_NAME'] || 'localhost'
    env = Hash.new
    env[ 'base' ] = ENV[ 'SCRIPT_NAME' ] || 'rw-cgi.rb'
    env[ 'base_url' ] = RWiki::Request.base_url(ENV)
    env[ 'server' ] = server_name + ((server_port == '80') ? '' : ':' + server_port)
    env[ 'rw-agent-info' ] = [ VERSION ]
# Recover these comment-out-ed lines and this proc will generates URL of
# RWiki name's references.  But bare in mind Proc cannot be dumped and Hash
# containing Proc cannot be dumped so a dRuby connection is needed per a
# reference generation.
#    env[ 'ref_name' ] = Proc.new { |cmd, name|
#	program = env[ 'base' ]
#	req = RWiki::Request.new(cmd, name)
#	program + "?" + req.query
#      }
    env
  end
end

