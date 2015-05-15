#!/usr/bin/env ruby
$LOAD_PATH.push '/opt/profeda/HelperClasses/lib/'
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

def main
  begin
    #dputs_func
    if !File.exists? @file_switch_versions
      if !File.exists? @file_update
        update_html("Didn't find #{@file_update}", '0')
        exit
      end
      file = IO.read(@file_update)
      update_html("Updating using file #{file}")
      update_html "Calling pacman to update #{file}"
      update = Thread.new {
        System.run_str '/usr/bin/killall -9 pacman'
        puts @pacman_lock
        File.exists?(@pacman_lock) and
            FileUtils.rm(@pacman_lock)
        puts System.run_str("/usr/bin/pacman --noconfirm --force -U #{file} > "+
                                '/tmp/gestion.update')
      }
      while update.alive?
        dputs(3) { 'Update is alive' }
        reverse_update = IO.read('/tmp/gestion.update').split("\n").reverse.join("\n")
        update_html("<pre>#{reverse_update}</pre>", true)
        sleep 4
      end
      dputs(3) { 'Update should be done' }
      FileUtils.rm @file_update
    else
      while File.exists? @file_update
        sleep 1
      end
      Service.stop('gestion')
    end
    update_html "<pre>#{IO.read('/tmp/gestion.update')}</pre>"
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
    update_html('Hope the update went well - goodbye',
                refresh: '5; URL=http://admin.profeda.org')
  rescue Exception => e
    update_html("Error: #{e.to_s} - #{e.inspect}")
    update_html("Error: #{caller.inspect}")
  end
  System.run_str "cat #{@html_file} | mail -S 'update gestion on $(hostname)' root@localhost"
end

def update_html(msg, noadd = false, refresh: '5')
  return unless Dir.exists? @html_dir
  p msg
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
  FileUtils.mv "#{@html_file}.tmp", @html_file
  noadd and @html_txt.pop
end

if ARGV.length > 0
  IO.write(@file_update, ARGV.first)
  update_html('Waiting to begin update')
else
  main
end
