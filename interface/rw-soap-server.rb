#!/usr/local/bin/ruby

$KCODE = 'EUC'	# SETUP
rwiki_uri = 'druby://localhost:8470' # SETUP
rwiki_log_dir = '/var/tmp'	# SETUP
use_as_cgi_stub = true	# SETUP

module RWiki
	module SOAP
		class RWikiControler
			ALLOW_GET_PAGE = false	# SETUP
		end
	end
end

require 'rwiki/soap-controller'

if use_as_cgi_stub
  # cgistub
  require 'soap/cgistub'
  server = SOAP::CGIStub.new('CGIStub', RWiki::SOAP::NS)
else
  # standalone server
  require 'soap/standaloneServer'
  server = SOAP::StandaloneServer.new('Standalone', RWiki::SOAP::NS,
                                      'localhost', 8080)
end

server.setLog(File.join(rwiki_log_dir, 'RWikiSOAPServer.log')) if rwiki_log_dir

DRb.start_service()
rwiki = DRbObject.new(nil, rwiki_uri)
server.addServant(RWiki::SOAP::Controller.new(rwiki))
server.start
