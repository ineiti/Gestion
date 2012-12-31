class AdminTigo < View
  def layout
    @update = true
    @auto_update = 10
    @auto_update_send_values = false
    @order = 20
    @tigo_number = Entities.Statics.get( :AdminTigo )

    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_int_ro :credit_left
          show_int_ro :promotion_left
          show_button :update_params, :connect, :disconnect
        end
        gui_vbox :nogroup do
          show_int :code, :width => 150
          show_button :recharge
        end
        gui_vbox :nogroup do
          show_list_drop :size, "%w( 30MB 100MB 1GB 5GB )"
          show_button :add_promotion
        end
      end
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_str :tigo_number
          show_button :update_tigo_number
        end
        gui_vbox :nogroup do
          show_html :status
        end
      end

      gui_window :error do
        show_html :msg
        show_button :close
      end
    end

  end

  def lib_net( func, r = nil )
    dputs( 3 ){ "Calling lib_net #{func} - #{r}" }
    ret = $lib_net.call( func, r )
    dputs( 3 ){ "returning from lib_net #{func}" }
    ret
  end

  def lib_net_args( func, *args )
    dputs( 3 ){ "Calling lib_net_args #{func}" }
    ret = $lib_net.call_args( func, args.join(' ') )
    dputs( 3 ){ "returning from lib_net #{func}" }
    ret
  end

  def rpc_update( session )
    buttons = reply( :unhide, :connect ) +
      reply( :hide, :disconnect )
    if $lib_net.call( :isp_connected ) == "yes"
      buttons = reply( :hide, :connect ) +
        reply( :unhide, :disconnect )
    end
    reply( :update, update( session ) ) +
      buttons
  end
	
  def rpc_show( session )
    super( session ) +
      rpc_update( session )
  end

  def rpc_button_connect( session, data )
    lib_net :isp_connect
    reply( :hide, :connect ) +
      reply( :unhide, :disconnect )
  end

  def rpc_button_disconnect( session, data )
    lib_net :isp_disconnect
    reply( :hide, :disconnect ) +
      reply( :unhide, :connect ) +
      rpc_update( session )
  end

  def rpc_button_recharge( session, data )
    code = data['code'].gsub( /[^0-9]/, '' )
    dputs( 0 ){ "Code is #{code}" }
    lib_net_args :isp_tigo_credit_add, code
    rpc_update( session ) + reply( :empty, [:code])
  end

  def rpc_button_add_promotion( session, data )
    lib_net_args :isp_tigo_promotion_add, data["size"]
    rpc_update( session )
  end

  def rpc_button_update_params( session, data )
    if `ifconfig` =~ /ppp0/
      dputs( 3 ){ "ppp0-link is up, can't update" }
      return reply( :update, { :msg => "Can't update while connected to Tigo!"}  ) +
        reply( :window_show, :error )
    else
      dputs( 3 ){ "No link, updating" }
      lib_net :isp_tigo_credit_update
      dputs( 3 ){ "Updating promotion" }
      lib_net :isp_tigo_promotion_update
      dputs( 3 ){ "Replying for update" }
      reply( 'update', update( session ) )
    end
  end

  def rpc_button_close( session, data )
    reply( :window_hide )
  end

  def rpc_button_update_tigo_number( session, data )
    reply( :update, :tigo_number => @tigo_number.data_str = data['tigo_number'] )
  end

  def update( session )
    { :credit_left => lib_net( nil, :CREDIT_LEFT ),
      :promotion_left => lib_net( nil, :PROMOTION_LEFT ),
      :tigo_number => @tigo_number.data_str,
      :status => "<pre>#{ lib_net( :isp_connection_status ) }</pre>" }
  end
end
