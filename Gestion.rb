#!/usr/bin/ruby -I../QooxView -wKU
# ! /opt/local/bin/ruby1.9 -I../QooxView -I. -wKU

# Gestion - a frontend for different modules developed in Markas-al-Nour
# N'Djaména, Tchad. The following modules shall be covered:
# - Login: - for payable laptop web-access
#          - for students

CONFIG_FILE="config.yaml"
if not FileTest.exists? CONFIG_FILE
  puts "Config-file doesn't exist"
  print "Do you want me to copy a standard one? [Y/n] "
  if gets.chomp.downcase != "n"
    %x[ cp config.yaml.default config.yaml ]
  end
end

DEBUG_LVL=3

begin
  require 'QooxView'
  require 'Captive'
  require 'QVInfo'
rescue Exception => e  
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
Permission.add( 'internet', 'SelfInternet', 'default' )
Permission.add( 'student', '', 'internet' )
Permission.add( 'assistant', 'TaskEdit', 'student' )
Permission.add( 'teacher', 'AdminAccess,CourseGrade,PersonModify', 'student' )
Permission.add( 'secretary', 'SelfCash,SelfServices,CourseModify,PersonAdd,PersonModify,CourseDiploma,FlagCourseGradeAll', 'teacher' )
Permission.add( 'accounting', 'TransferCash', 'secretary' )
Permission.add( 'admin', '.*', '.*' )

QooxView::init( 'Entities', 'Views' )

# Look for admin, create if it doesn't exist
admin = Entities.Persons.find_by_login_name( "admin" )
if not admin
  dputs 0, "OK, creating admin"
  admin = Entities.Persons.create( :login_name => "admin", :password => "super123", :permissions => [ "admin" ] ,
  :credit => "100" )
else
  admin.permissions = ["admin"];
end

if not Entities.Services.find_by_name( "Free solar" )
  dputs 0, "Creating services"
  Entities.Services.create( :name => "CCC", :group => "ccc", 
  :price => 1000, :duration => 0 )
  Entities.Services.create( :name => "CCC active", :group => "ccc_active", 
  :price => 5000, :duration => 30 )
  Entities.Services.create( :name => "Free solar", :group => "free_solar", 
  :price => 10000, :duration => 30 )
  Entities.Services.create( :name => "Free internet", :group => "free_internet", 
  :price => 25000, :duration => 30 )
end

# Autosave every 5 minutes
if $config[:autosave]
  $autosave = Thread.new{
    loop {
      sleep 60 * 5
      Entities.save_all
      Captive::check_services    
    }
  }
end

if $config[:profiling]
  require 'rubygems'
  require 'perftools'
  PerfTools::CpuProfiler.start("/tmp/#{$config[:profiling]}") do
    QooxView::startWeb
  end
else
  QooxView::startWeb
end

if $config[:autosave]
  $autosave.kill
  #Captive::check_services
end

Entities.save_all
