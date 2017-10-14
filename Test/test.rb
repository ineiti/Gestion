#!/usr/bin/env ruby
require 'bundler/setup'
require 'test/unit'
require 'fileutils'
FileUtils.rm_rf Dir.glob('data*')

$config_file='config_test.yaml'
DEBUG_LVL=0

require 'qooxview'
require 'network'
require 'africompta'
#ACQooxView.load_entities

def permissions_init
  Permission.clear
  Permission.add('default', 'View,Welcome')
  Permission.add('admin', '.*', '.*')
  Permission.add('internet', 'Internet,PersonShow', 'default')
  Permission.add('student', '', 'internet')
  Permission.add('teacher', 'FlagResponsible', 'student')
  Permission.add('secretary', 'PersonModify,FlagAddInternet,CashboxCredit',
                 'teacher')
  Permission.add('accountant', 'FlagAccounting')
  Permission.add('center', 'FlagAddCenter', 'teacher')
  Permission.add('director', 'FlagAddCenter', 'teacher')
end

permissions_init

dir = File.expand_path('..', __dir__)
QooxView.init("#{dir}/Entities", "#{dir}/Views")

tests = Dir.glob('ge_*.rb')
#tests = %w( activity )
#tests = %w( compta )
#tests = %w( internet )
# tests = %w( configbase )

$LOAD_PATH.push '.'
tests.each { |t|
  begin
    require "ge_#{t}"
  rescue LoadError => e
    require t
  end
}
