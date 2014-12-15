class SelfInternet < View
  include Network

  def layout
    set_data_class :Persons
    @order = 10
    @update = true
    @auto_update_async = 5
    @auto_update_send_values = false
    @functions_need = [:internet, :internet_captive]
    @functions_reject = [:internet_simple]

    gui_vbox do
      show_html :connection_status
      show_int_ro :internet_credit
      show_int_ro :users_connected
      show_int_ro :bytes_left
      show_int_ro :bytes_left_today
      show_html :connection, :width => 100
      show_html :auto_connection
      show_button :connect, :disconnect
    end
  end

  # 0 - yes
  # 1 - no money left
  # 2 - restrictions
  # 3 - AccessGroups-rules
  # 4 - no internet available
  def can_connect(session)
    return 4 unless Internet.operator
    if not (ag = AccessGroups.allow_user_now(session.owner))[0]
      return ag[1]
    elsif Captive.restricted
      return 2
    elsif Internet.free(session.owner)
      return 0
    else
      if session.owner and session.owner.internet_credit
        return (session.owner.internet_credit.to_i >= Internet.operator.user_cost_max) ?
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
    cc = can_connect(session)
    dputs(3) { "CanConnect is #{cc}" }
    case cc
      when 0
        status = Internet.device ? Internet.device.connection_status_old : 0
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
            'Etat de la connexion:<br>' +
                "<table width='150px'><tr>" +
                connection_status +
                '</tr></table>')
      when 1
        ret += reply(:update, :connection_status => 'Not enough money in account')
      when 2
        ret += reply(:update, :connection_status => 'Restricted access due to teaching')
      when 3
        ret += reply(:update, :connection_status => cc)
      when 4
        ret += reply(:update, :connection_status => 'No internet connection available')
    end
    return ret
  end

  def update_button(session, nobutton = false)
    if nobutton
      return reply(:hide, :connect) +
          reply(:hide, :disconnect) +
          reply(:update, :connection =>
              "<img src='/Images/connection_wait.png' height='50'>")

    end
    if not session.owner
      dputs(0) { "Error: no owner for session #{session.inspect}" }
      return
    end
    show_button = :connect
    connected = Captive.user_connected session.owner.login_name
    dputs(3) { "User #{session.owner.login_name} is connected: #{connected} " +
        "and can_connect = #{can_connect(session)}" }
    if can_connect(session) == 0
      dputs(3) { "User_connected #{session.owner.login_name}: #{connected.inspect}" }
      if connected
        dputs(4) { "Showing disconnect because we're connected" }
        show_button = :disconnect
      elsif Internet.operator &&
          Internet.operator.has_promo && Internet.operator.internet_left <= 100_000
        dputs(4) { 'Showing disconnect because there is no promotion left' }
        show_button = :disconnect
      end
    else
      dputs(3) { "User #{session.owner.login_name} has connected-status: #{connected.inspect}" }
      show_button = :disconnect
    end
    if show_button == :disconnect && !connected
      reply(:hide, [:connect, :disconnect])
    else
      reply_one_two(show_button == :connect, :connect, :disconnect)
    end +
        reply(:update, :connection =>
            "<img src='/Images/connection_#{connected ? 'yes' : 'no'}.png' height='50'>")
  end

  def update_isp(session)
    promo = (Internet.operator && Internet.operator.has_promo) ? :unhide : :hide
    dputs(3) { "promo is #{promo}: #{Internet.operator} - #{Internet.operator.has_promo.inspect}" }
    reply(promo, :bytes_left) +
        reply(promo, :bytes_left_today) +
        reply(:unhide, :connection_status)
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
            "#{users.count}: #{users_str}")
    if Internet.operator && Internet.operator.has_promo
      left = Internet.operator.internet_left
      ret += reply(:update, :bytes_left => left.to_MB('Mo')) +
          reply(:update, bytes_left_today: Recharge.left_today(left).to_MB('Mo'))
    end
    o = session.owner
    Captive.user_keep o.login_name, ConfigBase.keep_idle_free.to_i
    ret += reply(:update, auto_connection:
        'Bookmark for '+
            "<a href='http://internet.wifi/connect.cgi?user=#{o.login_name}&pass=#{o.password}'>" +
            'Internet-connection</a>')
    return ret
  end

  def rpc_show(session)
    super(session) +
        rpc_update(session)
  end

  def rpc_button_connect(session, data)
    if session.web_req
      log_msg :internet, "#{session.owner.login_name} connects with #{session.inspect}"
      Captive.user_connect session.owner.login_name, session.client_ip
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
