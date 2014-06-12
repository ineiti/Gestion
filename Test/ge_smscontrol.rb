DEBUG_LVL=3

require '../SMScontrol'

include Network
include HelperClasses::DPuts

if ! SMScontrol.modem
  puts 'No modem present'
  exit
end

SMScontrol.modem.set_2g
SMScontrol.make_connection
#SMScontrol.rb.modem.sms_send( 100, "internet" )

loop do
  SMScontrol.check_sms
  SMScontrol.check_connection
  dputs(0){ SMScontrol.state_to_s }
  sleep 10
end

exit

SMScontrol.check_connection
puts SMScontrol.state_to_s

SMScontrol.make_connection
puts SMScontrol.state_to_s

while SMScontrol.state_now != MODEM_CONNECTED
  sleep 10
  SMScontrol.check_connection
  puts SMScontrol.state_to_s
end
