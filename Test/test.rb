#!/usr/bin/ruby -I../../QooxView -wKU
require 'test/unit'

CONFIG_FILE="config_test.yaml"
DEBUG_LVL=4

require 'QooxView'

Permission.add( 'default', 'View,Welcome' )
Permission.add( 'admin', '.*', '.*' )
Permission.add( 'internet', 'Internet,PersonShow', 'default' )
Permission.add( 'student', '', 'internet' )
Permission.add( 'professor', '', 'student' )
Permission.add( 'secretary', 'PersonModify', 'professor' )

qooxView = QooxView.init( '../Entities', '../Views' )

require 'ge_person'
#require 'ge_login'
#require 'ge_view'
#require 'ge_tasks'
#require 'ge_course'
