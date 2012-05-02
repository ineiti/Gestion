class InternetTigo < View
  def layout
    @update = true

    gui_hbox do
      gui_vbox :nogroup do
        show_int_ro :credit_left
        show_int_ro :promotion_left
        show_button :update_params
      end
      gui_vbox :nogroup do
        show_int :code
	show_button :recharge
      end
      gui_vbox :nogroup do
        show_list_drop :size, "%w( 30MB 100MB 1GB 5GB )"
	show_button :add_promotion
      end

      gui_window :error do
        show_html :msg
        show_button :close
      end
    end
    
  end

  def lib_net( func, *args )
    `Binaries/lib_net func #{func.to_s} #{args.join(' ')}`
  end

  def rpc_button_recharge( session, data )
    code = data['code'].gsub( /[^0-9]/, '' )
    dputs 0, "Code is #{code}"
    lib_net :tigo_credit_add, code
    rpc_update( session )
  end

  def rpc_button_add_promotion( session, data )
    lib_net :tigo_promotion_add, data["size"]
    rpc_update( session )
  end

  def rpc_button_update_params( session, data )
    if `ifconfig` =~ /ppp0/
      dputs 3, "ppp0-link is up, can't update"
      return reply( :update, { :msg => "Can't update while connected to Tigo!"}  ) +
      reply( :window_show, :error )
    else
      dputs 3, "No link, updating"
      lib_net :tigo_credit_update
      lib_net :tigo_promotion_update
      reply( 'update', update( session ) )
    end
  end

  def rpc_button_close( session, data )
    reply( :window_hide )
  end

  def update( session )
    { :credit_left => lib_net( :tigo_credit_get ),
      :promotion_left => lib_net( :tigo_promotion_get ).to_i / 1000000.0 }
  end
end
