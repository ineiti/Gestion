#!/usr/bin/env ruby
# encoding: UTF-8
require './Dependencies'
Dependencies.load_path

require 'helperclasses'
include HelperClasses::System
include HelperClasses

Encoding.default_external = Encoding::UTF_8

# Gestion - a frontend for different modules developed in Markas-al-Nour
# N'Djaména, Tchad.

VERSION_GESTION='1.9.0'
require 'fileutils'

GESTION_DIR=File.dirname(__FILE__)
CONFIG_FILE='config.yaml'
if not FileTest.exists? CONFIG_FILE
  puts "Config-file doesn't exist"
  puts 'Do you want me to copy a standard one? [Y/n] '
  if gets.chomp.downcase != 'n'
    FileUtils.cp 'config.yaml.default', 'config.yaml'
  end
end

begin
  require 'QooxView'
  require 'ACQooxView'
  ACQooxView.load_entities
  Dependencies.load_dirs
rescue Exception => e
  puts "#{e.inspect}"
  puts "#{e.to_s}"
  puts e.backtrace

  puts "Couldn't start QooxView - perhaps missing libraries?"
  print 'Trying to run the installer? [Y/n] '
  if gets.chomp.downcase != 'n'
    puts 'Running installer'
    exec './Gestion --install -p'
  end
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
      'FlagAddInternet,CourseStats,CoursePrint,PersonActivity', 'assistant')
  Permission.add('accounting', 'ComptaTransfer,PersonCredit,FlagAccounting,' +
      'ComptaReport,ComptaShow,ComptaEdit.*,Cashbox.*,Report.*,' +
      'ComptaCheck', 'secretary')
  Permission.add('maintenance', 'Inventory.*', 'default')
  Permission.add('cybermanager', 'PersonCredit,NetworkTigo,FlagAddInternet,' +
      'FlagPersonAdd,CashboxService,NetworkSMS', '')
  Permission.add('director', 'FlagAdminCourse,FlagAdminPerson,AdminCourseType,AdminPower,' +
      'PersonAdmin,PersonCourse,NetworkConnection,CourseStats,Report.*,AdminBackup',
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

  dputs(1) { 'Loading database' }
  ACQooxView::check_db

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
  if get_config(true, :autosave)
    dputs(1) { 'Starting autosave' }
    $autosave = Thread.new {
      loop {
        sleep get_config(2 * 60, :autosave, :timer)
        rescue_all "Error: couldn't save all" do
          Entities.save_all
        end
      }
    }
  end

  if ConfigBase.has_function? :internet
    dputs(1) { 'Starting internet' }
    Internet.setup
    $internet = Thread.new {
      loop {
        rescue_all "Couldn't take internet-money" do
          if false
            dputs(0) { 'Internet-sleep is on 5!' }
            sleep 5
          else
            sleep 60
          end
          Internet::take_money
        end
      }
    }
  end

  if ConfigBase.has_function?(:sms_control)
    if na = ConfigBase.network_actions
      require na
    end
    dputs(1) { 'Starting sms-control' }
    $SMScontrol = Network::SMScontrol.new
    if ConfigBase.has_function? :sms_control_autocharge
      $SMScontrol.autocharge = true
    end

    $sms_control = Thread.new {
      loop {
        rescue_all 'Error with SMScontrol' do
          $SMScontrol.check_connection
          $SMScontrol.check_sms
          dputs(2) { $SMScontrol.state_to_s }
          sleep 10
        end
      }
    }
  end

  if get_config(false, :showTime)
    dputs(1) { 'Showing time' }
    $show_time = Thread.new {
      loop {
        sleep 60
        dputs(1) { 'It is now: ' + Time.now.strftime('%Y-%m-%d %H:%M') }
      }
    }
  end

  trap('SIGINT') {
    throw :ctrl_c
  }

  catch :ctrl_c do
    rescue_all 'Error: QooxView aborted' do
      log_msg :main, "Started Gestion on port #{webrick_port}"
      images_path = File.join(File.expand_path(File.dirname(__FILE__)), 'Images')
      RPCQooxdooHandler.add_file_path(:Images, images_path)
      QooxView::startWeb webrick_port
    end
  end

  if get_config(true, :autosave)
    $autosave.kill
  end

  $internet and $internet.kill
  $sms_control and $sms_control.kill
  $show_time and $show_time.kill

  Entities.save_all
end


