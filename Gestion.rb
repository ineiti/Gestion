#!/usr/bin/env ruby
# encoding: UTF-8

if ARGV == %w(-p)
  DEBUG_LVL = 0
else
  DEBUG_LVL = 2
end

require 'bundler/setup'
require 'helper_classes'
include HelperClasses
include System
$LOAD_PATH.push __dir__

Encoding.default_external = Encoding::UTF_8

# Gestion - a frontend for different modules developed in Markas-al-Nour
# N'Djaména, Tchad.

VERSION_GESTION='1.10.0' +
    (File.exists?('Gestion.pkgrel') ? '-' + IO.read('Gestion.pkgrel') : '')
require 'fileutils'

GESTION_DIR=File.expand_path(File.dirname(__FILE__))
$config_file='config.yaml'
if not FileTest.exists? $config_file
  puts "Config-file doesn't exist, copying a standard one"
  FileUtils.cp 'config.yaml.default', 'config.yaml'
end

begin
  require 'qooxview'
  require 'africompta'
  #ACQooxView.load_entities(false)
  %w( Modules Paths ).each { |dir|
    Dir.glob("#{dir}/*").each { |d| require d }
  }
rescue Exception => e
  puts "#{e.inspect}"
  puts "#{e.to_s}"
  puts e.backtrace
  exit
end

begin
  # Our default-permission is to only login!
  Permission.add('default', ',Welcome,SelfShow')
  Permission.add('quiz', 'SelfChat,SelfConcours,SelfResults', '')
  Permission.add('internet', 'SelfInternet,SelfChat', 'default')
  Permission.add('student', '', 'internet')
  Permission.add('librarian', 'LibraryPerson,FlagInternetFree', 'student')
  Permission.add('assistant', 'TaskEdit,FlagInternetFree', 'student')
  Permission.add('teacher', 'CourseGrade,PersonModify,NetworkRestriction,CoursePrint,' +
                              'FlagResponsible', 'assistant')
  Permission.add('center_director', '', 'center')
  Permission.add('secretary', 'CourseModify,FlagPersonAdd,FlagPersonDelete,' +
                                'PersonModify,CourseDiploma,FlagCourseGradeAll,Cashbox.*,' +
                                'FlagAddInternet,CourseStats,CoursePrint,' +
                                'CourseStudents,PersonCourse', 'assistant,cybermanager')
  Permission.add('accounting', 'ComptaTransfer,FlagAccounting,' +
                                 'ComptaReport,ComptaShow,ComptaEdit.*,Cashbox.*,Report.*,' +
                                 'ComptaCheck', 'secretary')
  Permission.add('maintenance', 'Inventory.*,AdminBackup,AdminPower,AdminFiles.*', 'default')
  Permission.add('cybermanager', 'CashboxCredit,FlagAddInternet,' +
                                   'FlagPersonAdd,CashboxService,InternetMobile,' +
                                    'CashboxActivity', '')
  Permission.add('manager', 'Template.*,Internet.*',
                              'director')
  Permission.add('director', 'FlagAdminCourse,FlagAdminPerson,' +
                               'PersonAdmin,PersonCourse,InternetConnection,CourseStats,Report.*,' +
                 'secretary,cybermanager,teacher')
  Permission.add('center', 'CourseModify,FlagAdminCourse,CourseGrade,' +
                             'FlagPersonAdd,FlagPersonDelete,PersonModify,CourseDiploma,' +
                             'FlagRemoteCourse,SelfShow,SelfChat,FlagAdminPerson,' +
                             'PersonCenter,FlagDeletePerson', '')
  Permission.add('admin', '.*', '.*')
  Permission.add('email', 'SelfEmail', '')

  QooxView::init('Entities', 'Views')

  # Look for admin, create if it doesn't exist
  admin = Entities.Persons.match_by_login_name('admin')
  if not admin
    dputs(1) { 'OK, creating admin' }
    admin = Entities.Persons.create(:login_name => 'admin', :password => 'super123', :permissions => ["admin"],
                                    :internet_credit => '100')
  else
    admin.permissions = ['admin'];
  end

rescue Exception => e
  case e.to_s
    when /UpdatePot|MakeMo|PrintHelp|value_entity_uncomplete/
    else
      puts e.inspect
      puts e.backtrace
      dputs(0) { "Error: Couldn't load things!" }
      dputs(0) { "#{e.inspect}" }
      dputs(0) { "#{e.to_s}" }
      puts e.backtrace
  end
  exit
end

webrick_port = get_config(3302, :Webrick, :port)
dputs(2) { "Starting at port #{webrick_port}" }

$profiling = get_config(nil, :profiling)
if $profiling
  dputs(1) { 'Starting Profiling' }
  require 'rubygems'
  require 'perftools'
  PerfTools::CpuProfiler.start("/tmp/#{$profiling}") do
    QooxView::startWeb webrick_port, get_config(30, :profiling, :duration)
    dputs(1) { 'Finished profiling' }
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
  if ConfigBase.autosave == %w(true)
    dputs(1) { 'Starting autosave' }
    $autosave = Thread.new {
      loop {
        sleep ConfigBase.autosave_timer.to_i
        rescue_all "Error: couldn't save all" do
          Entities.save_all
        end
      }
    }
  end

  # Initialize network and listen for new devices
  if ConfigBase.has_function? :network
    if !get_config(false, :Simulation)
      Network::Device.start
    end
  end

  # Start up internet-handling (traffic and credit)
  if ConfigBase.has_function? :internet
    dputs(1) { 'Starting internet' }
    Internet.setup
    $internet = Thread.new {
      loop {
        rescue_all "Couldn't take internet-money" do
          # Simple debug-routine to make it faster to test
          if false
            dputs(0) { 'Internet-sleep is on 5!' }
            sleep 5
            Internet.update_traffic
          else
            (1..6).each {
              sleep 10
              Internet.update_traffic
            }
          end
          Internet.take_money
        end
      }
    }
  end

  # Shows time every minute in the logs
  if get_config(false, :showTime)
    dputs(1) { 'Showing time' }
    $show_time = Thread.new {
      loop {
        sleep 60
        dputs(1) { 'It is now: ' + Time.now.strftime('%Y-%m-%d %H:%M') }
      }
    }
  end

  # Trying to debug mysterious slowdown
  if false
    $test_hash = {a: 1, b: 2, c: 3}
    $test_hash_big = (1..100).collect { |i| ["value#{i}", i] }.to_h
    $show_time = Thread.new {
      loop {
        Timing.measure('Small hash') { $test_hash._a }
        Timing.measure('Big hash') { $test_hash_big['value50'] }
        Timing.measure('Big method_missing') { $test_hash_big._value50 }
        sleep 10
      }
    }
  end

  # Catch SIGINT signal so we can save everything before quitting
  trap('SIGINT') {
    throw :ctrl_c
  }

  # Finally start QooxView
  catch :ctrl_c do
    rescue_all 'Error: QooxView aborted' do
      log_msg :main, "Started Gestion on port #{webrick_port}"
      images_path = File.join(File.expand_path(File.dirname(__FILE__)), 'Images')
      RPCQooxdooHandler.add_file_path(:Images, images_path)
      QooxView::startWeb webrick_port
    end
  end

  # Clean up all threads
  if get_config(true, :autosave)
    $autosave.kill
  end
  $internet and $internet.kill
  $show_time and $show_time.kill

  # And finally save all before quitting
  Entities.save_all
end
