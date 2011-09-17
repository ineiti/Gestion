class Welcome < View
  # Adds a session-id to a person and the appropriate permissions to the Permission-class
  def add_session( person )
    person.session_id = rand
    dputs 2, "Adding sid #{person.session_id} with #{person.permissions}"
    Permission.session_add( person.session_id, person.permissions )
    person.session_id
  end
  
  # Overwrite the standard rpc_show to speed up testing...
  def rpc_show(sid)
    if $config[:autologin]
      person = Entities.Persons.find_by_login_name( $config[:autologin] )
      dputs 3, "Found login #{person.data.inspect}" if person
      if person then
        add_session( person )
        return reply( "session_id", person.session_id ) +
        reply( "list", View.list( person.session_id ) )
      else
        return nil
      end
    else
      super
    end
  end

  # On pressing of the login-button, we search for the user and check the password
  def rpc_button_login( sid, args )
    dputs 3, "args is #{args.inspect}"
    login_name, password = args["username"], args["password"]
    person = Entities.Persons.find_by_login_name( login_name )
    dputs 5, "Person is #{person.inspect}"
    if person and person.check_pass( password ) then
      dputs 3, "Found login #{person.data_get(:person_id)} for #{login_name}"
      dputs 2, "Authenticated person #{person.login_name}"
      add_session( person )
      person.update_credit
      return reply( "session_id", person.session_id ) +
      reply( "list", View.list( person.session_id ) )
    else
      reply( "window_show", "login_failed" ) +
      reply( "update", {:reason => person ? "Password wrong" : "User doesn't exist" })
    end
  end

  # On logout
  def rpc_button_logout( sid )
    Permission.session_remove( sid )
    return super.rpc_show( sid )
  end
end
