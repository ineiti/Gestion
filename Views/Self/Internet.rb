class SelfInternet < View
  def layout
    set_data_class :Persons
    @order = 10
    @update = true
    @auto_update = 10
    @auto_update_send_values = false
    @functions_need = [:internet]
    @isp = $lib_net.isp_params

    gui_vbox do
      show_html :connection_status
      show_int_ro :internet_credit
      show_int_ro :users_connected
      show_int_ro :bytes_left
      show_button :connect, :disconnect
    end
  end
	
  # 0 - yes
  # 1 - no money left
  # 2 - restrictions
  # 3 - AccessGroups-rules
  def can_connect( session )
    if not ( ag = AccessGroups.allow_user_now( session.owner ) )[0]
      return ag[1]
    elsif $lib_net.get_var_file( :RESTRICTED ).join.length > 0
      return 2
    elsif Internet.free( session.owner )
      return 0
    else
      return session.owner.internet_credit.to_i >= $lib_net.print( :USER_COST_MAX ).to_i ? 
        0 : 1
    end
  end
	
  def update_connection_status( session )
    case (cc = can_connect( session ))
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
    else
      reply( :update, :connection_status => cc )
    end
  end
	
  def update_button( session, nobutton = false )
    if nobutton
      return reply( :hide, :connect ) +
        reply( :hide, :disconnect )
    end
    show_button = :connect
    connected = $lib_net.call( :user_connected, session.owner.login_name )
    if can_connect( session ) == 0
      dputs( 3 ){ "User_connected #{session.owner.login_name}: #{connected.inspect}" +
          " - #{@isp.inspect}" }
      if connected == "yes"
        dputs(4){"Showing disconnect because we're connected"}
        show_button = :disconnect
      elsif $lib_net.print( :PROMOTION_LEFT ).to_i == 0 and 
          @isp['has_promo'] == 'true'
        dputs(4){"Showing disconnect because there is no promotion left"}
        show_button = :disconnect
      end
    else
      dputs(3){"User #{session.owner.login_name} has connected-status: #{connected.inspect}" }
      show_button = :disconnect
    end
    if show_button == :connect
      return reply( :unhide, :connect ) +
        reply( :hide, :disconnect )
    else
      return reply( :hide, :connect ) +
        reply( :unhide, :disconnect )
    end
  end
  
  def update_isp( session )
    @isp = $lib_net.isp_params
    show_status = true
    #show_status = ( ( @isp['conn_type'] == 'ondemand' ) or 
    #    ( can_connect(session) == 0 ) )
    dputs(2){"isp-params is: #{@isp.inspect}, " +
        "show_status is #{show_status.inspect}"}
    reply( @isp['has_promo'] == 'true' ? :unhide : :hide, :bytes_left ) +
      reply( show_status ? :unhide : :hide, :connection_status )
  end
  
  def self.make_users_str( users )
    users_str = [[]]
    users.split.sort.each{|u|
      if users_str.last.count > 3
        users_str[-1] = users_str.last.join(", ")
        users_str.push []
      end
      users_str.last.push u
    }
    users_str[-1] = users_str.last.join(", ")
    users_str.join(",<br>")
  end

  def rpc_update( session, nobutton = false )
    users = $lib_net.call(:users_connected)
    users_str = SelfInternet.make_users_str( users )
    dputs(4){"session is #{session.inspect}"}
    ret = reply( :update, update( session ) ) +
      update_button( session, nobutton ) +
      update_connection_status( session ) +
      update_isp( session ) +
      reply( :update, :internet_credit => session.owner.internet_credit.to_i ) +
      reply( :update, :users_connected => 
        "#{users.split.count}: #{users_str}" )
    if @isp['has_promo'] == 'true'
      ret += reply( :update, :bytes_left => $lib_net.print( :PROMOTION_LEFT ) )
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
      $lib_net.async( :user_connect, "#{ip} #{session.owner.login_name}" )
      rpc_update( session, true )
    end
  end

  def rpc_button_disconnect( session, data )
    if session.web_req
      #ip = session.web_req.peeraddr[3]
      $lib_net.async( :user_disconnect_name, "#{session.owner.login_name}" )
      rpc_update( session, true )
    end
  end
end
