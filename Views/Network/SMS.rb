require 'network/modem'
require 'network/smscontrol'

class NetworkSMS < View
  include Network

  def layout
    @functions_need = [:sms_control]
    @order = 100
    @update = true
    @auto_update_async = 10
    @auto_update_send_values = false

    gui_hboxg do
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_str_ro :state_now
          show_str_ro :state_goal
          show_int_ro :transfer
          show_int_ro :promotion
          show_str_ro :emails
          show_str_ro :vpn
        end
        gui_vbox :nogroup do
          show_text :sms
          show_button :inject_sms
        end
        gui_vbox :nogroup do
          show_button :connect, :disconnect
        end
      end
      gui_vboxg :nogroup do
        show_text :sms_received, :flexheight => 1
      end
    end
  end

  def rpc_update(session)
    emails = system('which postqueue > /dev/null') ? %x[ postqueue -p | tail -n 1 ] : 'n/a'
    vpns = system( 'which systemctl > /dev/null') ?
        %x[ systemctl list-units --no-legend openvpn@* | sed -e "s/OpenVPN.*//" ] :
        %x[ pgrep openvpn ]
    reply(:update,
          :state_now => SMScontrol.state_now, :state_goal => SMScontrol.state_goal,
          :transfer => SMScontrol.state_traffic, :promotion => SMScontrol.max_traffic,
          :emails => emails, :vpn => vpns,
          :sms_received => SMSs.last(5).reverse.collect { |sms|
            "#{sms.date}::#{sms.phone}:: ::#{sms.text}"
          }.join("\n"))
  end

  def rpc_update_async(session)
    rpc_update(session)
  end

  def rpc_button_inject_sms(session, data)
    SMScontrol.inject_sms(data._sms)
  end

  def rpc_button_connect(session, data)
    SMScontrol.state_goal = Network::MODEM_CONNECTED
    rpc_update(session)
  end

  def rpc_button_disconnect(session, data)
    SMScontrol.state_goal = Network::MODEM_DISCONNECTED
    rpc_update(session)
  end
end
