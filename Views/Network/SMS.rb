class NetworkSMS < View
  def layout
    @functions_need = [:sms_control]
    @order = 100
    @update = true
    @auto_update = 30

    gui_vbox do
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
      gui_vbox :nogroup do
        show_button :emails, :vpn
      end
    end
  end

  def rpc_update(session)
    reply(:update,
          :state_now => SMScontrol.state_now, :state_goal => SMScontrol.state_now,
          :transfer => SMScontrol.state_traffic, :promotion => SMScontrol.max_traffic,
          :emails => %x[ postqueue -p | tail -n 1 ], :vpn => %x[ ps ax | grep openvpn ])
  end

  def rpc_button_inject_sms(session, data)

  end
end