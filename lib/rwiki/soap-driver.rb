require 'soap/driver'

require 'rwiki/soap-lib'

module RWiki
  module SOAP
    class Driver < ::SOAP::Driver
  
      APP_NAME = 'RWikiSOAPDriver'
      LOG_ID = 'RWikiSOAPDriver'

      def initialize(log_dir, endPoint, httpProxy=nil, soapAction=nil)
				log = nil
				unless log_dir.nil?
					log = Devel::Logger.new(File.join(log_dir, APP_NAME + '.log'),
																	'weekly')
					setWireDumpFileBase(File.join(log_dir, APP_NAME))
				end

        super(log, LOG_ID, RWiki::SOAP::NS, endPoint, httpProxy, soapAction)

        addMethod('allow_get_page')
        addMethod('page', 'name')

        addMethod('drb_host_and_port')

        addMethod('include', 'name')
        addMethod('find', 'str')
        addMethod('src', 'name')
        addMethod('body', 'name')
        addMethod('modified', 'name')
        addMethod('rd2content', 'src')
        addMethod('recent_changes')
        addMethod('copy', 'name', 'src')
        addMethod('append', 'name', 'src')
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
