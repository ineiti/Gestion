#!/usr/bin/ruby -I../../QooxView -I../../AfriCompta -I../../LibNet -wKU
require 'test/unit'

CONFIG_FILE="config_test.yaml"
DEBUG_LVL=3

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
  Permission.add( 'secretary', 'PersonModify', 'professor' )
end
permissions_init

qooxView = QooxView.init( '../Entities', '../Views' )

require 'ge_login'
require 'ge_view'
require 'ge_tasks'
require 'ge_internet'
require 'ge_info'
require 'ge_course'
require 'ge_person'
