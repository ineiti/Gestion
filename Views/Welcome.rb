class Welcome < View
  def dummy_for_translation
    show_str :username
    show_str :version
    show_str :direct_connect
    show_str :simple_connect
  end

  # Overwrite the standard rpc_show to speed up testing...
  def rpc_show(session)
    # GC.start
    web_req = session.web_req
    client_ip = RPCQooxdooHandler.get_ip(web_req)
    person = if get_config(false, :autologin)
               Entities.Persons.match_by_login_name(get_config(false, :autologin))
             else
               nil
             end
    if person
      person and dputs(3) { "Found login #{person.data.inspect}" }
      session = get_config(false, :multilogin) ? Sessions.find_by_owner(person.person_id) : nil
      session ||= Sessions.create(person)
      dputs(3) { "Session is #{session.inspect}" }
      return reply(:session_id, person.session_id) +
          View.rpc_list(session)
    else
      if session.web_req && ref = session.web_req.header._referer
        user, pass = ref.first.match(/user=(.*)&pass=(.*)/).to_a[1..2]
        if user && pass
          return rpc_button_direct_connect(session, {username: user, password: pass})
        end
      end
      Sessions.search_by_owner('[0-9]').each { |s|
        if s.last_seen && Time.now.to_i - s.last_seen.to_i <= 15
          log_msg :Welcome, "Found session #{s.inspect} from ip #{s.client_ip}"
          if s.client_ip == client_ip
            log_msg :Welcome, "Found session #{s.inspect} with correct ip"
            #dp person = session.owner
            #session = Sessions.create( person )
            return direct_connect(s)
          end
        end
      }
      super +
          reply(:update, :version => VERSION_GESTION) +
          reply(:update, :links => ConfigBase.welcome_text) +
          reply_visible(ConfigBase.has_function?(:internet_captive), :direct_connect)
    end
  end

  # On pressing of the login-button, we search for the user and check the password
  def rpc_button_simple_connect(session, args)
    #dputs_func
    dputs(3) { "args is #{args.inspect}" }
    login_name, password = args._username.gsub(/ /, '').downcase, args._password
    person = Persons.match_by_login_name(login_name)
    if person
      dputs(3) { "Person is #{person.inspect} and #{person.password}" }
    end
    if password.to_s.length == 0 then
      return reply(:focus, :password)
    elsif person and person.check_pass(password) then
      web_req = session.web_req
      session = Sessions.create(person)
      session.web_req = web_req
      session.client_ip = RPCQooxdooHandler.get_ip(web_req)
      dputs(3) { "Found login #{person.data_get(:person_id)} for #{login_name}" }
      dputs(3) { "Session is #{session.inspect}" }
      log_msg :Welcome, "Authenticated person #{person.login_name} from " +
                          "#{session.client_ip}"
      return reply(:session_id, person.session_id) +
          View.rpc_list(session)
    else
      reply(:window_show, :login_failed) +
          reply(:update, :reason => person ? 'Password wrong' : "User doesn't exist")
    end
  end

  def direct_connect(session)
    if !session or !session.owner
      return reply(:window_show, :login_failed) +
          reply(:update, :reason => 'Please enter a valid login')
    end

    if View.SelfInternet.can_connect(session) == 0
      dputs(2) { "Auto-connecting #{session.owner.login_name}" }
      View.SelfInternet.rpc_button_connect(session, nil)
    end

    tabs = View.list(session)._views

    dputs(3) { "Tabs starts as #{tabs.inspect}" }
    selftabs = tabs.find { |v| v.first == 'SelfTabs' }
    tabs.delete_if { |v| v.first == 'SelfTabs' }
    if selftabs
      tabs.unshift selftabs
    end

    dputs(3) { "Tabs is now #{tabs.inspect}" }
    return reply(:session_id, session.sid) +
        reply(:list, views: tabs) +
        (session.s_data._sub_tabs_only ? View.reply(:bar_position, 'top') : [])
  end

  def rpc_button_direct_connect(session, args)
    ret = rpc_button_simple_connect(session, args)
    if ret.first._cmd == :window_show
      return ret
    else
      session = Sessions.find_by_sid(ret.first._data)
      return direct_connect(session)
    end
  end

  # On logout
  def rpc_button_logout(session)
    session.close
    return super.rpc_show(session)
  end

end
