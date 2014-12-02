require 'network'
require 'helperclasses'

class NetworkSMS < View
  include Network

  def layout
    @functions_need = [:sms_control]
    @order = 10
    @update = true
    @auto_update_async = 10
    @auto_update_send_values = false

    gui_hboxg do
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_str_ro :state_now
          show_str_ro :state_goal
          show_int_ro :credit
          show_int_ro :promotion
          show_str_ro :emails
          show_str_ro :vpn
        end
        gui_vbox :nogroup do
          show_str :sms_number
          show_str :sms_text
          show_button :send_sms
        end
        gui_vbox :nogroup do
          show_str :ussd
          show_button :send_ussd, :add_credit, :credit_wo_recharge
        end
        gui_vbox :nogroup do
          show_button :connect, :disconnect, :recharge
        end
      end
      gui_vboxg :nogroup do
        show_text :sms_received, :flexheight => 1
        show_text :ussd_received, :flexheight => 1
        show_str_ro :operator
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
    ussds = $SMScontrol.device ? $SMScontrol.device.ussd_list.inspect : 'Down'
    operator = $SMScontrol.operator ? $SMScontrol.operator.name : ''
    reply(:update,
          :state_now => $SMScontrol.state_now, :state_goal => $SMScontrol.state_goal,
          :credit => $SMScontrol.operator.credit_left, :promotion => $SMScontrol.state_traffic,
          :emails => emails, :vpn => vpns,
          :sms_received => SMSs.last(5).reverse.collect { |sms|
            "#{sms.date}::#{sms.phone}:: ::#{sms.text}"
          }.join("\n"),
          :ussd_received => ussds,
          :operator => operator)
  end

  def rpc_update_async(session)
    rpc_update(session)
  end


  def rpc_button_send_sms(session, data)
    if data._sms_number.to_s.length == 0
      $SMScontrol.inject_sms(data._sms_text)
    else
      $SMScontrol.device.sms_send(data._sms_number, data._sms_text)
    end
  end

  def rpc_button_connect(session, data)
    $SMScontrol.operator.internet_left = 100_000_000
    $SMScontrol.state_goal = Device::CONNECTED
    rpc_update(session)
  end

  def rpc_button_disconnect(session, data)
    $SMScontrol.state_goal = Device::DISCONNECTED
    rpc_update(session)
  end

  def rpc_button_send_ussd(session, data)
    $SMScontrol.device.ussd_send(data._ussd)
    rpc_update(session)
  end

  def rpc_button_add_credit(session, data)
    $SMScontrol.operator.credit_add(data._ussd)
    rpc_update(session)
  end

  def rpc_button_credit_wo_recharge(session, data)
    $SMScontrol.recharge_hold = true
    $SMScontrol.operator.credit_add(data._ussd)
    rpc_update(session)
  end

  def rpc_button_recharge( session, data )
    $SMScontrol.recharge_hold = false
    $SMScontrol.recharge_all
  end
end
