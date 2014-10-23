class NetworkTigo < View
  def layout
    @visible = false
    @update = true
    @auto_update_async = 10
    @auto_update_send_values = false
    @order = 20
    @tigo_number = Entities.Statics.get( :AdminTigo )
    @functions_need = [:internet]
    @values_need = { :isp => :tigo }

    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_int_ro :credit_left
          show_int_ro :promotion_left
          show_int_ro :usage_day_mo
          show_button :update_params
        end
        gui_vbox :nogroup do
          show_int :code, :width => 150
          show_button :recharge
        end
        gui_vbox :nogroup do
          show_list_drop :size, "%w( 20MB 30MB 100MB 1GB 5GB )"
          show_button :add_promotion
        end
      end
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_str :tigo_number
          show_str_ro :tigo_recharge
          show_button :update_tigo_number
        end
        gui_vbox :nogroup do
          show_html :status
        end
        gui_vbox :nogroup do
          show_html :successful_promotions
          show_button :show_all_promotions
        end
      end
      
      gui_window :error do
        show_html :msg
        show_button :close
      end
    end
  end

  def rpc_update_async( session )
    reply( :update, update( session ).reject{|k,v| k == :tigo_number } )
  end
  
  def rpc_update( session )
    reply( :update, update( session ) )
  end
	
  def rpc_show( session )
    super( session ) +
      rpc_update( session )
  end

  def rpc_button_connect( session, data )
    $lib_net.async :isp_connect
    reply( :hide, :connect ) +
      reply( :unhide, :disconnect )
  end

  def rpc_button_disconnect( session, data )
    $lib_net.async :isp_disconnect
    reply( :hide, :disconnect ) +
      reply( :unhide, :connect ) +
      rpc_update( session )
  end

  def rpc_button_recharge( session, data )
    begin
      code = data['code'].gsub( /[^0-9]/, '' )
      dputs( 1 ){ "Code is #{code}" }
      $lib_net.async :isp_tigo_credit_add, code
    rescue NoMethodError
    end
    rpc_update( session ) + reply( :empty, [:code])
  end

  def rpc_button_add_promotion( session, data )
    $lib_net.call :isp_tigo_promotion_add, data["size"], session.owner.login_name
    rpc_update( session )
  end

  def rpc_button_update_params( session, data )
    $lib_net.call :isp_update_vars, :force
    return reply( :update, update( session ) )

    if `ifconfig` =~ /ppp0/
      dputs( 3 ){ "ppp0-link is up, can't update" }
      return reply( :update, { :msg => "Can't update while connected to Tigo!"}  ) +
        reply( :window_show, :error )
    else
      dputs( 3 ){ "No link, updating" }
      $lib_net.call :isp_tigo_credit_update
      dputs( 3 ){ "Updating promotion" }
      $lib_net.call :isp_tigo_promotion_update
      dputs( 3 ){ "Replying for update" }
      reply( :update, update( session ) )
    end
  end

  def rpc_button_close( session, data )
    reply( :window_hide )
  end

  def rpc_button_update_tigo_number( session, data )
    reply( :update, :tigo_number => @tigo_number.data_str = data['tigo_number'] )
  end

  def rpc_button_show_all_promotions( session, data )
    reply( :update, { :msg => "<pre>#{get_successful_promotions( true )}</pre>" } ) +
      reply( :window_show, :error )
  end

  def read_status
    str = case $lib_net.call( :isp_connection_status ) 
    when /0/
      "0/4 - Not connected"
    when /1/
      "1/4 - Opened modem"
    when /2/
      "2/4 - Password OK"
    when /3/
      "3/4 - Got IP"
    when /4/
      "4/4 - Secured connection"
    else
      ""
    end
    mode, stat, lac, ci = $lib_net.print( :ISP_TIGO_CELL ).split(",")
    rssi, ber = $lib_net.print( :ISP_TIGO_SIGNAL ).split(",")
    if stat == "1"
      antenna = case ci
      when /29/
        ":Bitkine1"
      when /2A/
        ":Bitkine2"
      when /2B/
        ":Bitkine3"
      when /AB7/
        ":Route Bitkine"
      else
        ":unknown"
      end
      str += "\nLocation: #{lac}\nAnteanna: #{ci + antenna}"
    else
      str += "\nNot registered"
    end
    str += "\nSignal: #{rssi.to_i}/31"
  end

  def get_successful_promotions( show_all = false )
    proms = [] #$lib_net.call( :isp_tigo_promotion_list ).split("\n").reverse
    if not show_all
      proms = proms[0..5]
    end
    proms.collect{|s|
      s.gsub(/ - .*user:/, '--' ).gsub(/ .*cost:/, '--' )
    }.join("\n")
  end

  def update( session )
    { :credit_left => $lib_net.print( :CREDIT_LEFT ),
      :promotion_left => $lib_net.print( :PROMOTION_LEFT ),
      :usage_day_mo => $lib_net.print( :USAGE_DAILY ).to_i / 1_000,
      :tigo_number => @tigo_number.data_str,
      :tigo_recharge => "*190*1234*235#{@tigo_number.data_str.gsub(/ /,'')}*800#",
      :status => "<pre>#{read_status}</pre>",
      :successful_promotions => "<pre>#{get_successful_promotions}</pre>" }
  end
end
