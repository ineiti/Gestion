require 'network'
require 'helper_classes'
require 'erb'


class MobileInfo < RPCQooxdooPath
  def self.parse(method, path, query)
    dputs(3) { "Got #{method} - #{path} - #{query}" }
    ERB.new(File.open('Files/mobileinfo.erb') { |f| f.read }).result(binding)
  end

  def self.send_email
    File.open('/tmp/status.html', 'w') { |f|
      f.write(ERB.new(File.open('Files/mobileinfo.erb') { |f| f.read }).result(binding))
    }
    System.run_bool('echo ".-=-." | mail -a /tmp/status.html -s "$( hostname ): Connected" root@localhost')
    log_msg :MobileInfo, 'Sent e-mail'
  end
end
