#!/usr/bin/env ruby
$LOAD_PATH.push '/opt/profeda/HelperClasses/lib/'
require 'helperclasses'
require 'net/http'
include HelperClasses

def main
  begin
    @html_txt = []
    @html_dir = '/srv/http/local'
    @html_file = "#{@html_dir}/update_progress.html"
    file_update = '/tmp/gestion.update'
    if ! File.exists? file_update
      update_html("Didn't find #{file_update}", '0')
      exit
    end
    file = IO.read(file_update)
    update_html("Updating using file #{file}")
    update_html 'Waiting for Gestion to stop for 10 seconds'
    Service.stop 'gestion'
    sleep 2
    update_html 'Waiting for Gestion to stop for 5 seconds'
    sleep 5
    update_html "Calling pacman to update #{file}"
    update = System.run_str "/usr/bin/pacman --noconfirm --force -U #{file}"
    update_html "<pre>#{update}</pre>"
    update_html 'Re-starting Gestion'
    Service.start 'gestion'
    i = 0
    uri = URI('http://localhost:3302')
    loop do
      sleep 4
      i += 1
      begin
        Net::HTTP.get(uri)
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
  System.run_str "cat #{@html_file} | mail -S 'update gestion on $(hostname)' root@localhost"
end

def update_html(msg, content = '5')
  return unless Dir.exists? @html_dir
  p msg
  @html_txt.push msg
  IO.write(@html_file, "
<html>
<head>
<META http-equiv='refresh' content='#{content}'>
  <meta http-equiv='Content-Type' content='text/html; charset=utf-8'/>
  <title>Update of Gestion</title>
  <style>
      body {
          background-color: #607860;
      }

      .center {
          text-align: center;
      }

      .right {
          text-align: right;
      }

      .main {
          margin-left: auto;
          margin-right: auto;
          padding: 10px;
          width: 70%;
          background-color: #b0deb0;
      }

      a:link {
          text-decoration: none;
          color: #000000;
      }

      a:visited {
          text-decoration: none;
          color: #000000;
      }

      a:hover {
          text-decoration: underline;
      }

      a:active {
          text-decoration: underline;
      }

      .big {
          font-size: 30px;
      }

      .medium {
          font-size: 20px;
      }

      .small {
          font-size: 10px;
      }
  </style>
</head>
<body>
<div class='main'>
<div class='center'>
<h1>Updating Gestion - please be patient</h1>
</div>
<ul>
#{@html_txt.collect { |t| "<li>#{t}</li>" }.join("\n")}
</ul>
</div>
</body>
</html>
")
end

main