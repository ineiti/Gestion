require '../SMScontrol'

include Network

if ! SMScontrol.modem
  puts 'No modem present'
  exit
end

loop do
  SMScontrol.check_sms
  SMScontrol.check_connection
  puts SMScontrol.state_to_s
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
