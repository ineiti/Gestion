class Welcome < View
  def dummy_for_translation
    show_str :username
    show_str :version
  end

  # Overwrite the standard rpc_show to speed up testing...
  def rpc_show( session )
    if get_config( false, :autologin )
      person = Entities.Persons.match_by_login_name( get_config( false, :autologin ) )
      person and dputs( 3 ){ "Found login #{person.data.inspect}" }
      if person then
        session = get_config( false, :multilogin ) ? Sessions.find_by_owner( person.person_id ) : nil
        session ||= Sessions.create( person )
        dputs(3){"Session is #{session.inspect}"}
        return reply( :session_id, person.session_id ) +
          View.rpc_list( session )
      else
        return nil
      end
    else
      if ( version_local = get_config( "", :version_local ) ) != ""
        version_local = "-#{version_local}"
      end
      super +
        reply( :update, :version => VERSION_GESTION + version_local ) +
        reply( :update, :links => get_config("", :welcome_text ) )
    end
  end

  # On pressing of the login-button, we search for the user and check the password
  def rpc_button_login( session, args )
    dputs( 3 ){ "args is #{args.inspect}" }
    login_name, password = args["username"].gsub(/ /,''), args["password"]
    person = Entities.Persons.match_by_login_name( login_name )
    if person
      dputs( 3 ){ "Person is #{person.inspect} and #{person.password}" }
    end
    if password.to_s.length == 0 then
      return reply( :focus, :password )
    elsif person and person.check_pass( password ) then
      web_req = session.web_req
      session = Sessions.create( person )
      session.web_req = web_req
      session.client_ip = RPCQooxdooHandler.get_ip( web_req )
      dputs( 3 ){ "Found login #{person.data_get(:person_id)} for #{login_name}" }
      dputs( 3 ){ "Session is #{session.inspect}" }
      dputs( 1 ){ "Authenticated person #{person.login_name} from #{session.client_ip} with session #{session.inspect}" }
      return reply( :session_id, person.session_id ) +
        reply( :list, View.list( session ) )
    else
      reply( :window_show, :login_failed ) +
        reply( :update, :reason => person ? "Password wrong" : "User doesn't exist" )
    end
  end

  # On logout
  def rpc_button_logout( session )
    session.close
    return super.rpc_show( session )
  end
end
