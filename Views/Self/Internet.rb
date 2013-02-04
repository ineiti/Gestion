class SelfInternet < View
  def layout
    set_data_class :Persons
    @order = 10
    @update = true
    @auto_update = 10
    @auto_update_send_values = false
    @isp = JSON.parse( $lib_net.call( :isp_params ) )

    gui_vbox do
      show_html :connection_status
      show_int_ro :credit
      show_int_ro :users_connected
      show_int_ro :bytes_left
      show_button :connect, :disconnect
    end
  end
	
  # 0 - yes
  # 1 - no money left
  # 2 - restrictions
  def can_connect( session )
    if $lib_net.call( :captive_restriction_get ).length > 0
      return 2
    elsif Internet.free( session.owner )
      return 0
    else
      return session.owner.credit.to_i >= $lib_net.call( :user_cost_max ).to_i ? 
        0 : 1
    end
  end
	
  def update_connection_status( session )
    case can_connect( session )
    when 0
      status = $lib_net.call( :isp_connection_status ).to_i
      status_str = %w( None PPP PAP IP VPN )
      status_color = %w( ff0000 ff2200 ff5500 ffff88 88ff88 )
      status_width = %w( 25 30 35 100 150 )
      connection_status = "<td width='#{status_width[status]}" + 
        "' bgcolor='" +
        status_color[status] + "'>" + 
        status_str[status] + "</td><td bgcolor='ffffff'></td>"

      reply( :update, :connection_status => 
          "Etat de la connexion:<br>" + 
          "<table width='150px'><tr>" + 
          connection_status +
          "</tr></table>" )
    when 1
      reply( :update, :connection_status => "Not enough money in account" )
    when 2
      reply( :update, :connection_status => "Restricted access due to teaching" )
    end
  end
	
  def update_button( session, nobutton = false )
    if nobutton
      return reply( :hide, :connect ) +
        reply( :hide, :disconnect )
    end
    connected = $lib_net.call_args( :user_connected, session.owner.login_name )
    if can_connect( session ) == 0
      dputs( 3 ){ "User_connected #{session.owner.login_name}: #{connected.inspect}" +
          " - #{@isp.inspect}" }
      if connected == "yes"
        dputs(4){"Showing disconnect"}
        return reply( :hide, :connect ) +
          reply( :unhide, :disconnect )
      elsif $lib_net.call( nil, :PROMOTION_LEFT ).to_i > 0 or 
          @isp['has_promo'] == 'false'
        dputs(4){"Showing connect"}
        return reply( :unhide, :connect ) +
          reply( :hide, :disconnect )
      end
    end
    dputs(3){"User #{session.owner.login_name} is connected: #{connected.inspect}" }
    if connected
      return reply( :hide, :connect ) +
        reply( :unhide, :disconnect )
    else
      return reply( :hide, :connect ) +
        reply( :hide, :disconnect )
    end
  end
  
  def update_isp( session )
    @isp = JSON.parse( $lib_net.call( :isp_params ) )
    show_status = ( ( @isp['conn_type'] == 'ondemand' ) or 
        ( can_connect(session) > 0 ) )
    dputs(2){"isp-params is: #{@isp.inspect}, " +
        "show_status is #{show_status.inspect}"}
    reply( @isp['has_promo'] == 'true' ? :unhide : :hide, :bytes_left ) +
      reply( show_status ? :unhide : :hide, :connection_status )
  end

  def rpc_update( session, nobutton = false )
    ret = reply( :update, update( session ) ) +
      update_button( session, nobutton ) +
      update_connection_status( session ) +
      update_isp( session ) +
      reply( :update, :users_connected => 
        $lib_net.call(:users_connected).split.count)
    if @isp['has_promo'] == 'true'
      ret += reply( :update, :bytes_left => $lib_net.call( nil, :PROMOTION_LEFT ) )
    end
    return ret
  end
	
  def rpc_show( session )
    super( session ) +
      rpc_update( session )
  end

  def rpc_button_connect( session, data )
    if session.web_req
      ip = session.web_req.peeraddr[3]
      $lib_net.call_args( :user_connect, "#{ip} #{session.owner.login_name}" )
      rpc_update( session, true )
    end
  end

  def rpc_button_disconnect( session, data )
    if session.web_req
      #ip = session.web_req.peeraddr[3]
      $lib_net.call_args( :user_disconnect_name, "#{session.owner.login_name}" )
      rpc_update( session, true )
    end
  end
end
