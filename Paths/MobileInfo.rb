require 'network'
require 'helperclasses'
require 'erb'


class Mobileinfo < RPCQooxdooPath
  def self.parse(method, path, query)
    dputs(3) { "Got #{method} - #{path} - #{query}" }
    ERB.new(File.open('Files/mobileinfo.erb') { |f| f.read }).result(binding)
  end

  def self.send_email
    File.open('/tmp/status.html', 'w') { |f|
      f.write(ERB.new(File.open('Files/mobileinfo.erb') { |f| f.read }).result(binding))
    }
    system('echo ".-=-." | mail -a /tmp/status.html -s "$( hostname ): Connected" root@localhost')
  end
end
