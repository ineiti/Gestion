#!/usr/bin/ruby -I../QooxView -I../AfriCompta -wKU
# ! /opt/local/bin/ruby1.9 -I../QooxView -I. -wKU

# Gestion - a frontend for different modules developed in Markas-al-Nour
# N'Djaména, Tchad. The following modules shall be covered:
# - Login: - for payable laptop web-access
#          - for students

DEBUG_LVL=2
VERSION_GESTION="1.1.9"
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

begin
  require 'QooxView'
  require 'Internet'
  require 'Info'
  require 'Label'
  require 'ACQooxView'
rescue Exception => e
  dputs( 0 ){ "#{e.inspect}" }
  dputs( 0 ){ "#{e.to_s}" }
  puts e.backtrace

  puts "Couldn't start QooxView - perhaps missing libraries?"
  print "Trying to run the installer? [Y/n] "
  if gets.chomp.downcase != "n"
    puts "Running installer"
    exec "./Gestion --install -p"
  end
  exit
end

# Our default-permission is to only login!
Permission.add( 'default', ',Welcome,SelfShow' )
Permission.add( 'internet', 'SelfInternet,SelfChat', 'default' )
Permission.add( 'student', '', 'internet' )
Permission.add( 'assistant', 'TaskEdit,FlagInternetFree', 'student' )
Permission.add( 'teacher', 'CourseGrade,PersonModify,NetworkRestriction', 'assistant' )
Permission.add( 'secretary', 'SelfServices,CourseModify,FlagAdminPerson,' + 
    'PersonModify,CourseDiploma,FlagCourseGradeAll', 'assistant' )
Permission.add( 'director', 'FlagAdminCourse,FlagAdminPerson', 'secretary' )
Permission.add( 'accounting', 'ComptaTransfer,PersonCredit,SelfCash,FlagAccounting', 'internet' )
Permission.add( 'maintenance', 'Inventory.*', 'default' )
Permission.add( 'cybermanager', 'SelfCash,PersonCredit,NetworkTigo,FlagAddInternet,SelfServices', '' )
Permission.add( 'center', 'CourseModify,FlagAdminCourse,CourseDiploma,' +
    'FlagRemoteCourse,SelfShow,SelfChat,FlagAdminPerson', 'teacher' )
Permission.add( 'admin', '.*', '.*' )

if uri = get_config( false, :LibNet, :URI )
  dputs(1){ "Making DRB-connection with #{uri}" }
  require 'drb'
  $lib_net = DRbObject.new nil, uri
  begin
    dputs(1){ "Connection is #{$lib_net.status}" }
  rescue DRb::DRbConnError
    dputs(0){ "Connection has been refused!" }
    dputs(0){ "Either start lib_net on #{uri} or remove LibNet-entry in config.yaml"}
    exit
  end
else
  begin
    require "../LibNet/LibNet.rb"
    $lib_net = LibNet.new
    dputs(0){ "Loaded Libnet" }
  rescue LoadError
    dputs(0){ "Couldn't load LibNet!" }
    $lib_net = nil
  end
end

QooxView::init( 'Entities', 'Views' )

# Look for admin, create if it doesn't exist
admin = Entities.Persons.match_by_login_name( "admin" )
#dputs(0){ admin.inspect }
#exit
if not admin
  dputs( 0 ){ "OK, creating admin" }
  admin = Entities.Persons.create( :login_name => "admin", :password => "super123", :permissions => [ "admin" ] ,
    :internet_credit => "100" )
else
  admin.permissions = ["admin"];
end

dputs( 0 ){ "Loading database" }
ACQooxView::check_db

if not Entities.Services.match_by_name( "Free solar" )
  dputs( 0 ){ "Creating services" }
  Entities.Services.create( :name => "CCC", :group => "ccc", 
    :price => 1000, :duration => 0 )
  Entities.Services.create( :name => "CCC active", :group => "ccc_active", 
    :price => 5000, :duration => 30 )
  Entities.Services.create( :name => "Free solar", :group => "free_solar", 
    :price => 10000, :duration => 30 )
  Entities.Services.create( :name => "Free internet", :group => "free_internet", 
    :price => 25000, :duration => 30 )
end

# Autosave every 2 minutes
if get_config( true, :autosave )
  $autosave = Thread.new{
    loop {
      sleep 2 * 60
      Entities.save_all
      Internet::check_services    
    }
  }
end

$internet = Thread.new{
  loop {
    begin
      sleep 60
      Internet::take_money
    rescue Exception => e
      dputs( 0 ){ "#{e.inspect}" }
      dputs( 0 ){ "#{e.to_s}" }
      puts e.backtrace
    end
  }
}

trap("SIGINT") { 
  throw :ctrl_c
}

$profiling = get_config( nil, :profiling )
catch :ctrl_c do
  begin
    webrick_port = get_config( 3302, :webrick, :port )
    dputs(2){"Starting at port #{webrick_port}" }
    if $profiling
      require 'rubygems'
      require 'perftools'
      PerfTools::CpuProfiler.start("/tmp/#{$profiling}") do
        QooxView::startWeb webrick_port
      end
    else
      QooxView::startWeb webrick_port
    end
  rescue Exception => e
  dputs( 0 ){ "#{e.inspect}" }
  dputs( 0 ){ "#{e.to_s}" }
  puts e.backtrace
    dputs( 0 ){ "Saving all" }
    Entities.save_all
  end
end

if get_config( true, :autosave )
  $autosave.kill
end
$internet.kill

if $profiling
  puts "Now run the following:
pprof.rb --pdf /tmp/#{$profiling} > /tmp/#{$profiling}.pdf
open /tmp/#{$profiling}.pdf
CPUPROFILE_FREQUENCY=500
    "
end
