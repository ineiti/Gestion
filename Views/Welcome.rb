class Welcome < View
  # Overwrite the standard rpc_show to speed up testing...
  def rpc_show( session )
    if $config[:autologin]
      person = Entities.Persons.find_by_login_name( $config[:autologin] )
      dputs 3, "Found login #{person.data.inspect}" if person
      if person then
        session = Session.new( person )
        return reply( "session_id", person.session_id ) +
        reply( "list", View.list( session ) )
      else
        return nil
      end
    else
      super
    end
  end

  # On pressing of the login-button, we search for the user and check the password
  def rpc_button_login( session, args )
    dputs 3, "args is #{args.inspect}"
    login_name, password = args["username"], args["password"]
    person = Entities.Persons.find_by_login_name( login_name )
    dputs 5, "Person is #{person.inspect}"
    if person and person.check_pass( password ) then
      dputs 3, "Found login #{person.data_get(:person_id)} for #{login_name}"
      dputs 2, "Authenticated person #{person.login_name}"
      session = Session.new( person )
      person.update_credit
      return reply( "session_id", person.session_id ) +
      reply( "list", View.list( session ) )
    else
      reply( "window_show", "login_failed" ) +
      reply( "update", {:reason => person ? "Password wrong" : "User doesn't exist" })
    end
  end

  # On logout
  def rpc_button_logout( session )
    session.close
    return super.rpc_show( session )
  end
end
