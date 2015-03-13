#!/usr/bin/env ruby
$LOAD_PATH.push '/opt/profeda/HelperClasses/lib/'
require 'helperclasses'
require 'net/http'
include HelperClasses

def main
  begin
    file = IO.read('/tmp/gestion.update')
    @html_txt = []
    update_html("Updating using file #{file}")
    Service.stop 'gestion'
    update_html 'Waiting for Gestion to stop for 10 seconds'
    sleep 5
    update_html 'Waiting for Gestion to stop for 5 seconds'
    sleep 5
    update_html "Calling pacman to update #{file}"
    update_html System.run_str "/usr/bin/pacman -U #{file}"
    update_html 'Re-starting Gestion'
    Service.start 'gestion'
    i = 0
    uri = URI('http://localhost:3302')
    loop do
      sleep 4
      i += 1
      begin
        HTTP.get(uri)
        break
      rescue Errno::ECONNREFUSED => e
        update_html("Count: #{i} - gestion not yet up and running")
      end
    end
    update_html('Hope the update went well - goodbye',
                '5; URL=http://admin.profeda.org')
  rescue Exception => e
    update_html("Error: #{e.to_s}")
    update_html("Error: #{caller.inspect}")
  end
end

def update_html(msg, content = '5')
  @html_txt.push msg
  IO.write('/srv/html/local/update_progress.html', "
<html>
<head>
<META http-equiv='refresh' content='#{content}'>
</head>
<body>
<h1>Updating Gestion - please be patient</h1>
<ul>
#{@html_txt.each { |t| "<li>#{t}</li>" }}
</ul>
</body>
</html>
")
end

main