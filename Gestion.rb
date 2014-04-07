#!/usr/bin/env ruby
# encoding: UTF-8
$LOAD_PATH.push( "../QooxView", ".", "../AfriCompta", "../LibNet" )
Encoding.default_external = Encoding::UTF_8

# Gestion - a frontend for different modules developed in Markas-al-Nour
# N'Djaména, Tchad. The following modules shall be covered:
# - Login: - for payable laptop web-access
#          - for students

DEBUG_LVL=0
VERSION_GESTION="1.4.1"
require 'fileutils'

GESTION_DIR=File.dirname(__FILE__)
CONFIG_FILE="config.yaml"
if not FileTest.exists? CONFIG_FILE
  puts "Config-file doesn't exist"
  print "Do you want me to copy a standard one? [Y/n] "
  if gets.chomp.downcase != "n"
    FileUtils.cp "config.yaml.default", "config.yaml"
  end
end

def cleanup_data
  puts "Oups - looking what to do"
  youngest = nil
  if File.exists? "Backups"
    youngest = %x[ ls Backups | sort | tail -n 1 ]
    puts "Backups are here - trying youngest: #{ youngest }"
  end
  puts "Making new backup and deleting everything in data/*"
  %x[ Binaries/backup 1rescue_ ]
  exec "nohup Binaries/swipe_gestion -f #{youngest}"
  #FileUtils.rm_rf( "data" )
  #youngest and exec "nohup Binaries/restore #{ youngest } &"
  #%x[ echo Binaries/start_gestion | at now+1min ]
  #%x[ pkill -9 -f tee.*gestion ]
  #exit
end

begin
  HAS_CONFIGBASE=true
  require 'QooxView'
  require 'Internet'
  require 'Info'
  require 'Label'
  require 'GetDiplomas'
  require 'ACQooxView'
  ACQooxView.load_entities
rescue StorageLoadError
  cleanup_data
rescue Exception => e
  puts "#{e.inspect}"
  puts "#{e.to_s}"
  puts e.backtrace

  puts "Couldn't start QooxView - perhaps missing libraries?"
  print "Trying to run the installer? [Y/n] "
  if gets.chomp.downcase != "n"
    puts "Running installer"
    exec "./Gestion --install -p"
  end
  exit
end

begin
  # Our default-permission is to only login!
  Permission.add( 'default', ',Welcome,SelfShow' )
  Permission.add( 'quiz', 'SelfChat,SelfConcours,SelfResults', '' )
  Permission.add( 'internet', 'SelfInternet,SelfChat', 'default' )
  Permission.add( 'student', '', 'internet' )
  Permission.add( 'assistant', 'TaskEdit,FlagInternetFree', 'student' )
  Permission.add( 'teacher', 'CourseGrade,PersonModify,NetworkRestriction,CoursePrint,' +
      'FlagResponsible', 'assistant' )
  Permission.add( 'secretary', 'SelfServices,CourseModify,FlagPersonAdd,FlagPersonDelete,' + 
      'PersonModify,CourseDiploma,FlagCourseGradeAll,Cashbox.*,' +
      'FlagAddInternet', 'assistant' )
  Permission.add( 'accounting', 'ComptaTransfer,PersonCredit,SelfCash,FlagAccounting,' +
      'ComptaReport,ComptaShow', 'internet' )
  Permission.add( 'maintenance', 'Inventory.*', 'default' )
  Permission.add( 'cybermanager', 'SelfCash,PersonCredit,NetworkTigo,FlagAddInternet,' +
      'FlagPersonAdd,SelfServices', '' )
  Permission.add( 'director', 'FlagAdminCourse,FlagAdminPerson,AdminCourseType,AdminPower,' +
      'PersonAdmin,PersonCourse,NetworkConnection,CourseStats', 
    'secretary,cybermanager,teacher' )
  Permission.add( 'center', 'CourseModify,FlagAdminCourse,CourseDiploma,CourseGrade,' +
      'FlagRemoteCourse,SelfShow,SelfChat,FlagAdminPerson', '' )
  Permission.add( 'admin', '.*', '.*' )

  QooxView::init( 'Entities', 'Views' )

  # Look for admin, create if it doesn't exist
  admin = Entities.Persons.match_by_login_name( "admin" )
  if not admin
    dputs( 1 ){ "OK, creating admin" }
    admin = Entities.Persons.create( :login_name => "admin", :password => "super123", :permissions => [ "admin" ] ,
      :internet_credit => "100" )
  else
    admin.permissions = ["admin"];
  end

  dputs( 1 ){ "Loading database" }
  ACQooxView::check_db
  
  if not Entities.Services.match_by_name( "Free solar" )
    dputs( 1 ){ "Creating services" }
    Entities.Services.create( :name => "CCC", :group => "ccc", 
      :price => 1000, :duration => 0 )
    Entities.Services.create( :name => "CCC active", :group => "ccc_active", 
      :price => 5000, :duration => 30 )
    Entities.Services.create( :name => "Free solar", :group => "free_solar", 
      :price => 10000, :duration => 30 )
    Entities.Services.create( :name => "Free internet", :group => "free_internet", 
      :price => 25000, :duration => 30 )
  end

rescue StorageLoadError
  cleanup_data
  #rescue DRb::DRbConnError
  #  dputs(0){ "Error: Connection to LibNet has been refused!" }
  #  dputs(0){ "Error: Either start lib_net on #{uri} or remove LibNet-entry in config.yaml"}
  #  exit
rescue Exception => e
  case e.to_s
  when /UpdatePot|MakeMo|PrintHelp/
  else
    puts e.inspect
    puts e.backtrace
    dputs(0){ "Error: Couldn't load LibNet!" }
    dputs( 0 ){ "#{e.inspect}" }
    dputs( 0 ){ "#{e.to_s}" }
    puts e.backtrace
  end
  exit
end

webrick_port = get_config( 3302, :Webrick, :port )
dputs(2){"Starting at port #{webrick_port}" }

$profiling = get_config( nil, :profiling )
if $profiling
  dputs(1){"Starting Profiling"}
  require 'rubygems'
  require 'perftools'
  PerfTools::CpuProfiler.start("/tmp/#{$profiling}") do
    QooxView::startWeb webrick_port, get_config( 30, :profiling, :duration )
    dputs(1){"Finished profiling"}
  end
  
  if $profiling
    puts "Now run the following:
pprof.rb --pdf /tmp/#{$profiling} > /tmp/#{$profiling}.pdf
open /tmp/#{$profiling}.pdf
CPUPROFILE_FREQUENCY=500
    "
  end
else
  # Autosave every 2 minutes
  if get_config( true, :autosave )
    dputs(1){"Starting autosave"}
    $autosave = Thread.new{
      loop {
        Entities.save_all
        Internet::check_services    
        sleep get_config( 2 * 60, :autosave, :timer )
      }
    }
  end

  if ConfigBase.has_function? :internet
    dputs(1){"Starting internet"}
    $internet = Thread.new{
      loop {
        begin
          sleep 60
          if ConfigBase.has_function? :internet_only
            Internet::fetch_cash
          end
          Internet::take_money
        rescue Exception => e
          dputs( 0 ){ "Error: couldn't take internet-money" }
          dputs( 0 ){ "#{e.inspect}" }
          dputs( 0 ){ "#{e.to_s}" }
          puts e.backtrace
        end
      }
    }
  end
  
  if get_config( false, :showTime )
    dputs(1){"Showing time"}
    $internet = Thread.new{
      loop {
        sleep 60
        dputs( 1 ){ "It is now: " + Time.now.strftime( "%Y-%m-%d %H:%M" ) }
      }
    }
  end

  trap("SIGINT") { 
    throw :ctrl_c
  }

  catch :ctrl_c do
    begin
      log_msg :main, "Started Gestion on port #{webrick_port}"
      QooxView::startWeb webrick_port
    rescue Exception => e
      dputs( 0 ){ "Error: QooxView aborted" }
      dputs( 0 ){ "#{e.inspect}" }
      dputs( 0 ){ "#{e.to_s}" }
      puts e.backtrace
    end    
  end

  if get_config( true, :autosave )
    $autosave.kill
  end
  
  $internet and $internet.kill

  Entities.save_all
end


