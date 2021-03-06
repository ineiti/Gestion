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

    gui_hbox do
      gui_vbox :nogroup do
        show_html :connection_status
        show_int_ro :internet_credit
        show_int_ro :users_connected
        show_int_ro :bytes_left
        show_int_ro :bytes_left_today
        show_html :connection, :width => 100
        show_html :auto_connection
        show_button :connect, :disconnect
      end
      gui_vbox :nogroup do
        show_table :traffic, headings: %w(Name Day-2 Day-1 Today),
                   widths: [100, 75, 75, 75]
        show_button :disconnect_user
      end
    end
  end

  # 0 - yes
  # 1 - no money left
  # 2 - restrictions
  # 3 - AccessGroups-rules
  # 4 - no internet available
  def can_connect(session)
    # dputs_func
    noop = Internet.operator == nil
    dputs(3) { "noop is #{noop}" }
    return 4 if noop
    if not (ag = AccessGroups.allow_user_now(session.owner))[0]
      dputs(3) { "AccessGroup is #{ag}" }
      return ag[1]
    elsif Captive.restricted
      dputs(3) { 'Restricted' }
      return 2
    elsif Internet.free(session.owner)
      dputs(3) { 'Internet free' }
      return 0
    else
      dputs(3) { 'Looking for money' }
      if session.owner and session.owner.internet_credit
        cost_max = 20
        if Internet.operator
          cost_max = Internet.operator.user_cost_max
        end
        return (session.owner.internet_credit.to_i >= cost_max) ?
            0 : 1
      else
        dputs(0) { "Error: Called with session.owner == nil! #{session.inspect}" }
        return 1
      end
    end
  end

  def update_connection_status(session)
    #dputs_func
    return reply(:hide, :connection_status) unless session.owner.has_role(:cybermanager)
    ret = []
    cc = can_connect(session)
    dputs(3) { "CanConnect is #{cc}" }
    case cc
      when 0
        status, status_str = Internet.connection_status
        dputs(3) { "Connection-status is #{status.inspect}" }
        status = status.to_i
        if (0..4).include? status.to_i
          status_color = %w( ff0000 ff2200 ff5500 ffff88 88ff88 )
          status_width = %w( 25 30 35 100 150 )
          connection_status = "<td width='#{status_width[status]}" +
              "' bgcolor='" +
              status_color[status] + "'>" +
              status_str + "</td><td bgcolor='ffffff'></td>"
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
    #dputs_func
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
                         "<img src='/Images/connection_#{connected ? 'yes' : 'no'}.png' height='50'>") +
        reply_visible(session.owner.is_responsible?, :disconnect_user)
  end

  def update_isp(session)
    promo = (Internet.operator && Internet.operator.has_promo)
    dputs(3) { "promo is #{promo}: #{Internet.operator} - #{Internet.operator.has_promo.inspect}" }
    reply_visible(promo && session.owner.is_staff?, :bytes_left) +
        reply(:unhide, :connection_status)
  end

  def self.make_users_str(users)
    users_str = [[]]
    users.split.sort.each { |u|
      if users_str.last.count > 3
        users_str[-1] = users_str.last.join(', ')
        users_str.push []
      end
      users_str.last.push u
    }
    users_str[-1] = users_str.last.join(', ')
    users_str.join(',<br>')
  end

  def rpc_update_async(session)
    rpc_update(session)
  end

  def traffic_rxtx(t)
    t.collect { |r, t| r+t }.join('-')
  end

  def get_traffic(user)
    return reply(:hide, :traffic) unless (t = Captive.traffic) && user.is_staff?
    list = t.traffic.collect { |h, _k|
      traffic = t.get_day(h, -3).collect { |r, t| ((r+t)/1000)/1000.0 }
      [h, [h] + traffic]
    }.select { |t| t[1][1..3].inject(:+) > 0
    }.sort_by { |t| t[1][3] }.reverse
    #list = [[:ineiti], [20, 30, 40]]
    reply(:unhide, :traffic) +
        reply(:update, traffic: list)
  end

  def rpc_update(session, nobutton = false)
    if nobutton
      nobutton = Internet.operator &&
          Internet.operator.connection_type == Operator::CONNECTION_ONDEMAND
    end
    o = session.owner

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
        reply(:update, :internet_credit => o.internet_credit.to_i) +
        reply(:update, :users_connected => "#{users.count}: #{users_str}") +
        reply_visible(!Internet.free(session.owner), :internet_credit)
    if Internet.operator && Internet.operator.has_promo && o.is_staff?
      left = Internet.operator.internet_left
      ret += reply(:unhide, :bytes_left) +
          reply(:update, :bytes_left => left.to_MB('Mo'))
      if Recharges.enabled?
        ret += reply(:unhide, :bytes_left_today) +
            reply(:update, bytes_left_today: Recharge.left_today(left).to_MB('Mo'))
      else
        ret += reply(:hide, :bytes_left_today)
      end
    else
      ret += reply(:hide, %w(bytes_left bytes_left_today))
    end

    Captive.user_keep o.login_name, ConfigBase.keep_idle_free.to_i, true
    url = 'Bookmark for<br>'+ "<a href='http://#{session.web_req.header._host.first}/" +
        "?user=#{o.login_name}&pass=#{o.password}'>" +
        'Internet-connection</a>'

    ret + reply(:update, auto_connection: url) +
        get_traffic(o)
  end

  def rpc_show(session)
    super(session) +
        rpc_update(session)
  end

  def rpc_button_connect(session, data)
    if session.web_req
      log_msg :internet, "#{session.owner.login_name} connects with #{session.inspect}"
      Internet.user_connect session.owner.login_name, session.client_ip
      rpc_update(session, true)
    end
  end

  def rpc_button_disconnect(session, data)
    if session.web_req
      log_msg :internet, "#{session.owner.login_name} disconnects"
      Internet.user_disconnect session.owner.login_name
      rpc_update(session, true)
    end
  end

  def rpc_button_disconnect_user(session, data)
    return unless session.owner.is_responsible?
    data._traffic.each { |u|
      log_msg :internet, "#{session.owner.login_name} disconnects #{u}"
      Internet.user_disconnect u
      rpc_update(session, true)
    }
  end

end
