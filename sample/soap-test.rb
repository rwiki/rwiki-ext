#!/usr/bin/env ruby

require "rwiki/soap/driver"

$KCODE = 'EUC'	# SETUP
soap_server_uri =
         'http://localhost/~rwiki/rw-soap.rb' # for CGIStub
# 'http://localhost:8080/' # for StandaloneServer
  
driver = RWiki::SOAP::Driver.new("/tmp", soap_server_uri)

%w(top hoooo).each do |name|
  puts "test using name #{name}"
  puts driver.include(name)
  p driver.find(name)
  puts driver.src(name)
  puts driver.modified(name)
end
#puts "copy test"
#puts driver.copy('hoge', '((<test>))')
#puts "appned test"
#puts driver.append('hoge', '((<top>))')
