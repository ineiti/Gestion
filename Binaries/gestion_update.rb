#!/usr/bin/env ruby
require 'bundler/setup'
require 'helper_classes'
require 'net/http'
require 'fileutils'

include HelperClasses
include HelperClasses::DPuts

@file_update = '/tmp/gestion.update'
@file_switch_versions = '/tmp/gestion.switch_versions'
@html_txt = []
@html_dir = '/srv/http/local'
@pacman_lock = '/var/lib/pacman/db.lck'
@html_file = "#{@html_dir}/update_progress.html"
DEBUG_LVL = 2

def reverse_update
  return unless File.exists?(@file_update)
  "#{Time.now.to_s }<br><textarea rows='20' cols='100'>" +
      IO.read(@file_update).split("\n").reverse.join("\n") +
      '</textarea>'
end

def main
  begin
    update_content = ''
    if !File.exists? @file_switch_versions
      if !File.exists? @file_update
        update_html("Didn't find #{@file_update}", '0')
        exit
      end
      file = IO.read(@file_update)
      update_html('Stopping Gestion')
      Service.stop('gestion')
      update_html("Updating using file #{file}")
      update_html "Calling pacman to update #{file}"
      update = Thread.new {
        System.run_str '/usr/bin/killall -9 pacman'
        puts @pacman_lock
        File.exists?(@pacman_lock) and
            FileUtils.rm(@pacman_lock)
        puts System.run_str("/usr/bin/pacman --noconfirm --force -U #{file} > "+
                                @file_update)
      }
      while update.alive?
        dputs(3) { 'Update is alive' }
        update_html(reverse_update, true)
        sleep 4
      end
      dputs(3) { 'Update should be done' }
      update_content = reverse_update
      FileUtils.rm @file_update
    else
      update_content = reverse_update
      FileUtils.rm @file_switch_versions
      while File.exists? @file_update
        sleep 1
      end
      Service.stop('gestion')
    end
    update_html update_content
    update_html 'Starting Gestion'
    Service.reload
    Service.start('gestion')
    i = 0
    uri = URI('http://localhost:3302')
    loop do
      sleep 4
      i += 1
      begin
        Net::HTTP.get(uri)
        update_html("OK, we're good")
        break
      rescue Errno::ECONNREFUSED => e
        update_html("Count: #{i} - gestion not yet up and running", true)
      end
    end
    update_html('Hope the update went well -
                 <a href="http://admin.profeda.org" target="other">Login</a>',
                refresh: '86400',
                script: "setTimeout(function(){
                           window.open('http://admin.profeda.org', '_blank');
                         }, 5000 );")
  rescue StandardError => e
    update_html("Error: #{e.to_s} - #{e.inspect}")
    update_html("Error: #{caller.inspect}")
  end
  System.run_str "cat #{@html_file} | mail -S 'update gestion on $(hostname)' root@localhost"
end

def update_html(msg, noadd = false, refresh: '5', script: '')
  return unless Dir.exists? @html_dir
  p msg unless noadd
  @html_txt.push msg
  IO.write("#{@html_file}.tmp", "
<html>
<head>
<META http-equiv='refresh' content='#{refresh}'>
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

      textarea {
          background-color: #d0ded0;
      }

      a:link {
          text-decoration: underline;
          color: #6666AA;
      }

      a:visited {
          text-decoration: underline;
          color: #6666AA;
      }

      a:hover {
          text-decoration: underline;
          color: #66AA66;
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
<script type='text/javascript'>
#{script}
</script>
</body>
</html>
")
  FileUtils.mv "#{@html_file}.tmp", @html_file
  noadd and @html_txt.pop
end

if ARGV.length > 0
  IO.write(@file_update, ARGV.first)
  update_html('Waiting to begin update')
else
  main
end
