#!/usr/bin/ruby -I../../QooxView -I../../AfriCompta -I../../LibNet -wKU
require 'test/unit'

CONFIG_FILE="config_test.yaml"
DEBUG_LVL=2

require 'QooxView'
require 'ACQooxView'
require 'LibNet'

$lib_net = LibNet.new

def permissions_init
  Permission.clear
  Permission.add( 'default', 'View,Welcome' )
  Permission.add( 'admin', '.*', '.*' )
  Permission.add( 'internet', 'Internet,PersonShow', 'default' )
  Permission.add( 'student', '', 'internet' )
  Permission.add( 'professor', '', 'student' )
  Permission.add( 'secretary', 'PersonModify,FlagAddInternet', 'professor' )
  Permission.add( 'accountant', 'FlagAccounting' )
end
permissions_init

QooxView.init( '../Entities', '../Views' )


tests = %w( login view tasks internet info course person )
tests = %w( course )
tests.each{|t|
  require "ge_#{t}"
}
