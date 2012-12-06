class Welcome < View
  # Overwrite the standard rpc_show to speed up testing...
  def rpc_show( session )
    if $config[:autologin]
      person = Entities.Persons.find_by_login_name( $config[:autologin] )
      person and dputs( 3 ){ "Found login #{person.data.inspect}" }
      if person then
        session = Session.new( person )
        return reply( "session_id", person.session_id ) +
        reply( "list", View.list( session ) )
      else
        return nil
      end
    else
      if ( version_local = get_config( "", :version_local ) ) != ""
        version_local = "-#{version_local}"
      end
      super +
        reply( :update, :version => VERSION + version_local )
    end
  end

  # On pressing of the login-button, we search for the user and check the password
  def rpc_button_login( session, args )
    dputs( 3 ){ "args is #{args.inspect}" }
    login_name, password = args["username"].gsub(/ /,''), args["password"]
    person = Entities.Persons.find_by_login_name( login_name )
    if person
      dputs( 3 ){ "Person is #{person.inspect} and #{person.password}" }
    end
    if person and person.check_pass( password ) then
      dputs( 3 ){ "Found login #{person.data_get(:person_id)} for #{login_name}" }
      dputs( 2 ){ "Authenticated person #{person.login_name}" }
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
