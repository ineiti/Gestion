class SelfInternet < View
  def layout
    set_data_class :Persons
    @order = 10
    @update = true
    @auto_update_async = 10
    @auto_update_send_values = false
    @functions_need = [:internet]
    @functions_reject = [:internet_simple]

    gui_vbox do
      show_html :connection_status
      show_int_ro :internet_credit
      show_int_ro :users_connected
      show_int_ro :bytes_left
      show_html :connection, :width => 100
      show_button :connect, :disconnect
    end
  end

  # 0 - yes
  # 1 - no money left
  # 2 - restrictions
  # 3 - AccessGroups-rules
  def can_connect(session)
    if not (ag = AccessGroups.allow_user_now(session.owner))[0]
      return ag[1]
    elsif Captive.restricted
      return 2
    elsif Internet.free(session.owner)
      return 0
    else
      if session.owner and session.owner.internet_credit
        return session.owner.internet_credit.to_i >= Operator.user_cost_max ?
            0 : 1
      else
        dputs(0) { "Error: Called with session.owner == nil! #{session.inspect}" }
        return 1
      end
    end
  end

  def update_connection_status(session)
    return reply(:hide, :connection_status) unless session.owner.has_role(:cybermanager)
    ret = reply(Internet.free(session.owner) ? :hide : :unhide, :internet_credit)
    case (cc = can_connect(session))
      when 0
        status = Connection.status
        dputs(3) { "Connection-status is #{status.inspect}" }
        status = status.to_i
        if (0..4).include? status.to_i
          status_str = %w( None PPP PAP IP VPN )
          status_color = %w( ff0000 ff2200 ff5500 ffff88 88ff88 )
          status_width = %w( 25 30 35 100 150 )
          connection_status = "<td width='#{status_width[status]}" +
              "' bgcolor='" +
              status_color[status] + "'>" +
              status_str[status] + "</td><td bgcolor='ffffff'></td>"
        else
          dputs(0) { "Error: connection-status was #{status.inspect}" }
          connection_status = 'Comm-error'
        end

        ret += reply(:update, :connection_status =>
            "Etat de la connexion:<br>" +
                "<table width='150px'><tr>" +
                connection_status +
                "</tr></table>")
      when 1
        ret += reply(:update, :connection_status => "Not enough money in account")
      when 2
        ret += reply(:update, :connection_status => "Restricted access due to teaching")
      else
        ret += reply(:update, :connection_status => cc)
    end
    return ret
  end

  def update_button(session, nobutton = false)
    if nobutton
      return reply(:hide, :connect) +
          reply(:hide, :disconnect)
    end
    if not session.owner
      dputs(0) { "Error: no owner for session #{session.inspect}" }
      return
    end
    show_button = :connect
    connected = Captive.user_connected session.owner.login_name
    if can_connect(session) == 0
      dputs(3) { "User_connected #{session.owner.login_name}: #{connected.inspect}" }
      if connected == "yes"
        dputs(4) { "Showing disconnect because we're connected" }
        show_button = :disconnect
      elsif Operator.internet_left <= 100_000 and Operator.has_promo
        dputs(4) { 'Showing disconnect because there is no promotion left' }
        show_button = :disconnect
      end
    else
      dputs(3) { "User #{session.owner.login_name} has connected-status: #{connected.inspect}" }
      show_button = :disconnect
    end
    if show_button == :connect
      return reply(:unhide, :connect) +
          reply(:hide, :disconnect) +
          reply(:update, :connection => '<img src="/Images/connection_no.png" height="50">')
    else
      return reply(:hide, :connect) +
          reply(:unhide, :disconnect) +
          reply(:update, :connection => '<img src="/Images/connection_yes.png" height="50">')
    end
  end

  def update_isp(session)
    show_status = true
    dputs(3) { "show_status is #{show_status.inspect}" }
    reply(Operator.has_promo ? :unhide : :hide, :bytes_left) +
        reply(show_status ? :unhide : :hide, :connection_status)
  end

  def self.make_users_str(users)
    users_str = [[]]
    users.split.sort.each { |u|
      if users_str.last.count > 3
        users_str[-1] = users_str.last.join(", ")
        users_str.push []
      end
      users_str.last.push u
    }
    users_str[-1] = users_str.last.join(", ")
    users_str.join(",<br>")
  end

  def rpc_update_async(session)
    rpc_update(session)
  end

  def rpc_update(session, nobutton = false)
    users = Captive.users_connected
    users_str = SelfInternet.make_users_str(users)
    dputs(4) { "session is #{session.inspect}" }
    if session.class != Session
      dputs(0) { "Called rpc_update without a session! #{caller.inspect}" }
    end
    ret = reply(:update, update(session)) +
        update_button(session, nobutton) +
        update_connection_status(session) +
        update_isp(session) +
        reply(:update, :internet_credit => session.owner.internet_credit.to_i) +
        reply(:update, :users_connected =>
            "#{users.split.count}: #{users_str}")
    if Operator.has_promo
      ret += reply(:update, :bytes_left => Operator.internet_left)
    end
    return ret
  end

  def rpc_show(session)
    super(session) +
        rpc_update(session)
  end

  def rpc_button_connect(session, data)
    if session.web_req
      log_msg :internet, "#{session.owner.login_name} connects"
      Captive.user_connect session.client_ip, session.owner.login_name
      rpc_update(session, true)
    end
  end

  def rpc_button_disconnect(session, data)
    if session.web_req
      log_msg :internet, "#{session.owner.login_name} disconnects"
      Captive.user_disconnect_name session.owner.login_name
      rpc_update(session, true)
    end
  end
end
