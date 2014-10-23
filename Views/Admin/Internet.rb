class AdminInternet < View
  extend Network

  def layout
    @visible = false

    set_data_class :Persons

    @update = true
    @auto_update = 30
    @auto_update_send_values = false
    @order = 25

    gui_hbox do
      gui_vbox :nogroup do
        show_int_ro :credit_left
        show_int_ro :promotion_left
        show_list_drop :auto_disconnect, '[:No,:Yes]', :callback => :auto_disconnect
        show_button :connect, :disconnect, :delete_emails
      end
      gui_vbox :nogroup do
        show_html :mails
        show_html :transfer
      end
    end

    @file_ad = '/var/run/poff_after_email'
  end

  def auto_disconnect_get
    dputs(3) { "Auto disconenct with #{@file_ad} and #{File.exists? @file_ad}" }
    File.exists?(@file_ad) ? 'Yes' : 'No'
  end

  def update(session)
    emails = %x[ tail -n 1 /var/log/copy_email.log ]
    {:credit_left => Operator.credit_left,
     :promotion_left => Operator.internet_left,
     :mails => "<pre>#{ Mail.get_queue}</pre>",
     :transfer => "<pre>#{ emails } </pre>",
     :auto_disconnect => [auto_disconnect_get]}
  end

  def rpc_update(session)
    buttons = reply(:unhide, :connect) +
        reply(:hide, :disconnect)
    if Connection.status == Connection::CONNECTED
      buttons = reply(:hide, :connect) +
          reply(:unhide, :disconnect)
    end
    reply(:update, update(session)) +
        buttons
  end

  def rpc_show(session)
    super(session) +
        rpc_update(session)
  end

  def rpc_button_connect(session, data)
    Connection.start
    rpc_update(session)
  end

  def rpc_button_disconnect(session, data)
    Connection.stop
    rpc_update(session)
  end

  def rpc_button_delete_emails(session, data)
    Mail.start_copy
    rpc_show(session)
  end

  def rpc_list_choice(session, name, *args)
    dputs(3) { args.inspect }
    if args[0]['auto_disconnect']
      value = args[0]['auto_disconnect'][0]
      dputs(3) { "Going to set #{value}" }
      if value and value == 'Yes'
        File.new(@file_ad, 'w').close
      else
        if auto_disconnect_get == 'Yes'
          File.unlink(@file_ad)
        end
      end
    end
  end
end
