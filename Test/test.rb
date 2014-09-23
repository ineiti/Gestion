#!/usr/bin/env ruby
require '../Dependencies'
Dependencies.load_path( here: '..')
require 'test/unit'

CONFIG_FILE="config_test.yaml"
DEBUG_LVL=0

require 'QooxView'
require 'ACQooxView'
require 'LibNet'
require '../Paths/Label'
require '../Paths/ICC'
ACQooxView.load_entities

def permissions_init
  Permission.clear
  Permission.add( 'default', 'View,Welcome' )
  Permission.add( 'admin', '.*', '.*' )
  Permission.add( 'internet', 'Internet,PersonShow', 'default' )
  Permission.add( 'student', '', 'internet' )
  Permission.add( 'teacher', 'FlagResponsible', 'student' )
  Permission.add( 'secretary', 'PersonModify,FlagAddInternet', 
    'teacher' )
  Permission.add( 'accountant', 'FlagAccounting' )
  Permission.add( 'center', 'FlagAddCenter', 'teacher')
  Permission.add( 'director', 'FlagAddCenter', 'teacher')
end
permissions_init

%x[ rm -rf data* ]

$lib_net = LibNet.new( true )

QooxView.init( '../Entities', '../Views' )

tests = %w( compta configbase course info internet login person qvinfo
            report share sms tasks usage view )
#tests = %w( sms )
tests = %w( course )
#tests = %w( configbase )
tests.each{|t|
  require "ge_#{t}"
}
