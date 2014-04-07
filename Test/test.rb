#!/usr/local/bin/ruby -I.. -I../../QooxView -I../../AfriCompta -I../../LibNet -I.
#!/usr/bin/ruby -I.. -I../../QooxView -I../../AfriCompta -I../../LibNet -I. -wKU
require 'test/unit'

CONFIG_FILE="config_test.yaml"
DEBUG_LVL=3

require 'QooxView'
require 'ACQooxView'
require 'LibNet'
require 'Label'
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
end
permissions_init

%x[ rm -rf data* ]

$lib_net = LibNet.new( true )

QooxView.init( '../Entities', '../Views' )

tests = %w( login view tasks internet info course person )
tests = %w( person )
#tests = %w( configbase )
tests.each{|t|
  require "ge_#{t}"
}
