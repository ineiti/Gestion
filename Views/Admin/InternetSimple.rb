class AdminInternet < View
  def layout
    set_data_class :Persons

    @update = true
    @auto_update = 30
    @auto_update_send_values = false

    gui_hbox do
      gui_vbox :nogroup do
        show_int_ro :credit_left
        show_int_ro :promotion_left
        show_list_drop :auto_disconnect, "[:No,:Yes]", :callback => true
        show_button :connect, :disconnect
      end
      gui_vbox :nogroup do
        show_html :mails
        show_html :transfer
      end
    end

    @file_ad = "/var/run/poff_after_email"
  end

  def lib_net( func, *args )
    `Binaries/lib_net func #{func.to_s} #{args.join(' ')}`
  end

  def auto_disconnect_get
    dputs 0, "Auto disconenct with #{@file_ad} and #{File.exists? @file_ad}"
    File.exists?( @file_ad ) ? "Yes" : "No"
  end

  def update( session )
    { :credit_left => lib_net( :tigo_credit_get ),
      :promotion_left => lib_net( :tigo_promotion_get ).to_i / 1000000.0,
      :mails => "<pre>#{ lib_net( :mail_get_queue )}</pre>",
      :transfer => "<pre>#{ `tail -n 1 /var/log/copy_email.log` }</pre>",
      :auto_disconnect => [auto_disconnect_get] }
  end

  def rpc_show( session )
    to_hide = ( `ifconfig` =~ /ppp0/ ) ? :connect : :disconnect
    super( session ) + [{ :cmd => "update", :data => update( session )}] +
      reply( :hide, to_hide )
  end

  def rpc_button_connect( session, data )
    `pon tigo`
    reply( :hide, :connect ) +
    reply( :unhide, :disconnect )
  end

  def rpc_button_disconnect( session, data )
    `while poff -a; do sleep 1; done`
    reply( :hide, :disconnect ) +
    reply( :unhide, :connect )
  end

  def rpc_list_choice( session, name, *args )
    dputs 0, args.inspect
    if args[0]['auto_disconnect']
      value = args[0]['auto_disconnect'][0]
      dputs 3, "Going to set #{value}"
      if value and value == "Yes"
        File.new( @file_ad, "w" ).close
      else
        if auto_disconnect_get == "Yes"
          File.unlink( @file_ad )
        end
      end
    end
  end
end
