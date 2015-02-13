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
    @umts_netctl = '/etc/netctl/umts'
    if !File.exists?(@umts_netctl)
      # For testing purposes
      @umts_netctl = '/tmp/umts'
    end
    i=0
    @umts_modes = %w(3Gpref 3Gonly GPRSpref GPRSonly).map { |m| [i+=1, m] }

    gui_hboxg do
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_str_ro :operator
          show_int_ro :credit
          show_int_ro :promotion
          show_int_ro :promotion_left
          show_str_ro :state_now
          show_str_ro :state_goal
          show_str_ro :emails
          show_str_ro :vpn
          show_list_drop :umts_connection, 'View.NetworkSMS.umts_connection',
                         :callback => true
          show_button :connect, :disconnect, :reload
        end
        gui_vbox :nogroup do
          show_str :sms_number
          show_str :sms_text
          show_button :send_sms
        end
        gui_vbox :nogroup do
          show_str :ussd
          show_button :send_ussd, :add_credit
          show_split_button :recharge, []
        end
      end
      gui_vboxg :nogroup do
        show_text :sms_received, :flexheight => 1
        show_text :ussd_received, :flexheight => 1
      end
    end
  end

  def umts_connection
    ret = @umts_modes
    if File.exists?(@umts_netctl)
      mode = IO.readlines(@umts_netctl).
          select { |l| l =~ /^\#{0,1}Mode/ }.first.
          match(/.*=(.*)/)[1]
      index = @umts_modes.select { |i, m| m == mode }.first[0]
      index ? ret + [index] : ret
    else
      ret
    end
  end

  def rpc_list_choice_umts_connection(session, data)
    if File.exists?(@umts_netctl)
      file = IO.readlines(@umts_netctl).map { |l|
        if l =~ /^(\#{0,1}Mode)/
          "#{$1}=#{@umts_modes[data._umts_connection.first-1][1]}"
        else
          l.chomp
        end
      }
      IO.write(@umts_netctl, file.join("\n"))
    end
  end

  def s_unknown(i)
    i == -1 ? 'Unknown' : i
  end

  def s_status(i)
    case i
      when Device::CONNECTED
        'Connected'
      when Device::CONNECTING
        'Connecting'
      when Device::DISCONNECTING
        'Disconnecting'
      when Device::DISCONNECTED
        'Disconnected'
      when Device::ERROR_CONNECTION
        'Error'
      when -1
        'Unknown'
    end
  end

  def recharges_list
    return 'No recharge possible' if $SMScontrol.operator_missing?
    list = $SMScontrol.operator.internet_cost_available.reverse.
        collect { |c, v|
      "#{c} CFAs for #{(v.to_i/1_000_000).separator} MB" }
    list.size == 0 ? 'No recharge possible' : list
  end

  def rpc_update(session)
    return unless $SMScontrol
    cl, il, recharge = if $SMScontrol.operator_missing?
                         [-1, -1, 'No recharge possible']
                       else
                         [$SMScontrol.operator.credit_left,
                          $SMScontrol.operator.internet_left,
                         recharges_list]
                       end
    #cl, il = s_unknown(cl), s_unknown(il)
    emails = System.exists?('postqueue') ?
        System.run_str('postqueue -p | tail -n 1') : 'n/a'
    vpns = System.exists?('systemctl') ?
        System.run_str('systemctl list-units --no-legend openvpn@* | '+
                           'sed -e "s/OpenVPN.*//"') :
        System.run_str('pgrep openvpn')
    vpns
    ussds = $SMScontrol.device ? $SMScontrol.device.ussd_list : 'Down'
    operator = $SMScontrol.operator ? $SMScontrol.operator.name : 'Unknown'
    reply(:update,
          :state_now => s_status($SMScontrol.state_now),
          :state_goal => s_status($SMScontrol.state_goal),
          :credit => cl,
          :promotion => il.separator,
          :promotion_left => Recharge.left_today(il).separator,
          :emails => emails, :vpn => vpns,
          :sms_received => SMSs.last(5).reverse.collect { |sms|
            "#{sms.date}::#{sms.phone}:: ::#{sms.text}"
          }.join("\n"),
          :ussd_received => ussds,
          :recharge => recharge,
          :operator => operator) +
        reply_visible(Recharges.enabled?, :promotion_left) +
        reply_visible(File.exists?(@umts_netctl), :umts_connection)
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
    if $SMScontrol.operator.internet_left.to_i <= 1_000_000
      $SMScontrol.operator.internet_left = 100_000_000
    end
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
    $SMScontrol.recharge_hold = true
    $SMScontrol.operator.credit_add(data._ussd)
    rpc_update(session)
  end

  def rpc_button_recharge(session, data)
    dp data
    if data._menu.to_s.length == 0
      if $SMScontrol.operator_missing?
        credit = 0
      else
        credit = $SMScontrol.operator.internet_cost_available.reverse.first[0].to_i
      end
    else
      credit = data._menu.match(/^[0-9]*/)[0].to_i
    end
    if credit > 0
      log_msg :NetworkSMS, "Asking for recharge of #{credit}"
      $SMScontrol.recharge_hold = false
      $SMScontrol.recharge_all(credit)
    end
    rpc_update(session)
  end

  def rpc_button_reload(session, data)
    rpc_update(session)
  end
end
