require 'logger'
require 'soap/rpc/driver'

require 'rwiki/soap-lib'

module RWiki
  module SOAP
    class Driver < ::SOAP::RPC::Driver
  
      APP_NAME = 'RWikiSOAPDriver'

      def initialize(log_dir, end_point, http_proxy=nil, soap_action=nil)
        super(end_point, RWiki::SOAP::NS, soap_action)
				unless log_dir.nil?
					self.wiredump_file_base = File.join(log_dir, APP_NAME)
				end
				self.httpproxy = http_proxy

        add_method('allow_get_page')
        add_method('page', 'name')

        add_method('drb_host_and_port')

        add_method('include', 'name')
        add_method('find', 'str')
        add_method('src', 'name')
        add_method('body', 'name')
        add_method('modified', 'name')
        add_method('revision', 'name')
        add_method('rd2content', 'src')
        add_method('recent_changes')
        add_method('copy', 'name', 'src')
        add_method('append', 'name', 'src')
        add_method('submit', 'name', 'src', 'rev', 'log')
      end
      
    end
  end
end

if __FILE__ == $0
      
  $KCODE = 'EUC'	# SETUP
  soap_server_uri =
    'http://localhost/~kou/rwiki/rw-soap-server.rb' # for CGIStub
    # 'http://localhost:8080/' # for StandaloneServer
  
  driver = RWiki::SOAP::Driver.new(RWiki::SOAP::LOG_DIR, soap_server_uri)

  %w(top hoooo).each do |name|
    puts "test using name #{name}"
    puts driver.include(name)
    p driver.find(name)
    puts driver.src(name)
    puts driver.body(name)
    puts driver.modified(name)
  end
  puts "copy test"
  puts driver.copy('hoge', '((<test>))')
  puts "appned test"
  puts driver.append('hoge', '((<top>))')
end
