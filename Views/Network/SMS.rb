require 'network'

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
          show_str :sms_fake
          show_button :inject_sms
        end
        gui_vbox :nogroup do
          show_str :sms_number
          show_str :sms_text
          show_button :send_sms
        end
        gui_vbox :nogroup do
          show_str :ussd
          show_button :send_ussd
        end
        gui_vbox :nogroup do
          show_button :connect, :disconnect
        end
      end
      gui_vboxg :nogroup do
        show_text :sms_received, :flexheight => 1
        show_text :ussd_received, :flexheight => 1
        show_list_drop :operator, 'Network::Operator.operators'
      end
    end
  end

  def rpc_update(session)
    emails = System.exists?('postqueue') ?
        System.run_str('postqueue -p | tail -n 1') : 'n/a'
    vpns = System.exists?('systemctl') ?
        System.run_str('systemctl list-units --no-legend openvpn@* | '+
                           'sed -e "s/OpenVPN.*//"') :
        System.run_str('pgrep openvpn')
    reply(:update,
          :state_now => $SMScontrol.state_now, :state_goal => $SMScontrol.state_goal,
          :transfer => $SMScontrol.state_traffic, :promotion => $SMScontrol.state_traffic,
          :emails => emails, :vpn => vpns,
          :sms_received => SMSs.last(5).reverse.collect { |sms|
            "#{sms.date}::#{sms.phone}:: ::#{sms.text}"
          }.join("\n"),
          :ussd_received => $SMScontrol.device.ussd_list.inspect)
  end

  def rpc_update_async(session)
    rpc_update(session)
  end

  def rpc_button_inject_sms(session, data)
    $SMScontrol.inject_sms(data._sms_fake)
  end

  def rpc_button_send_sms(session, data)
    $SMScontrol.modem.sms_send(data._sms_number, data._sms_text)
  end

  def rpc_button_connect(session, data)
    $SMScontrol.state_goal = Device::CONNECTED
    rpc_update(session)
  end

  def rpc_button_disconnect(session, data)
    $SMScontrol.state_goal = Device::DISCONNECTED
    rpc_update(session)
  end

  def rpc_button_send_ussd(session, data)
    begin
      $SMScontrol.modem.ussd_send(data._ussd)
    rescue 'USSDinprogress' => e
    end
    rpc_update(session)
  end
end
