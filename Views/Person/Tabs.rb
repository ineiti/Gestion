class PersonTabs < View
  def layout
    @order = 10
    @update = true

    gui_vboxg :nogroup do
      show_list_single :persons, "[]", :callback => true
      show_str :search #, :callback => :search
      show_button :start_search, :delete
      #show_button :start_test
			
      gui_window :test do
        show_str :hello
        show_button :close
      end
    end
  end
	
  def rpc_button_start_test( session, args )
    sleep 2
    reply( :window_show, :test )
  end
	
  def rpc_button_close( session, args )
    sleep 2
    reply( :window_hide )
  end
  
  def rpc_button_start_search( session, args )
    rpc_callback_search( session, args )
  end
  
  def rpc_button_delete( session, args )
    if session.can_view( :FlagDeletePerson )
      if ( p_login = args["persons"] ) and 
          ( p = Persons.match_by_login_name( p_login[0] ) )
        ddputs(3){"Found person #{p.inspect} - #{p.class.name}"}
        p.delete
        rpc_callback_search( session, args )
      end
    end
  end
  
  def rpc_update_view( session, args = nil )
    super( session, args ) +
      reply( :focus, :search ) +
      reply( session.can_view( :FlagDeletePerson ) ? :unhide : :hide, :delete )
  end
  
  def rpc_list_choice( session, name, args )
    dputs( 2 ){ "args is #{args.inspect}" }
    dputs( 2 ){ "New choice #{name} - #{args['persons']}" }

    if name == 'persons' and args and args['persons']
      reply( :pass_tabs, [ "list_choice", name, { :persons => [ args['persons'] ] } ] )
    else
      []
    end
  end

  def rpc_callback_search( session, data, do_list_choice = true )
    dputs( 2 ){ "Got data: #{data.inspect}" }

    s = data['search']

    # Don't search if there are few caracters and lots of Persons
    if ( not s or s.length < 3 ) and ( Entities.Persons.new_id.values[0] > 100 )
      return reply( :focus, :search )
    end
		
    result = %w( login_name family_name first_name 
        permissions person_id email phone ).collect{|f|
      ret = Entities.Persons.search_by( f, s )
      if session.owner.permissions.index( "center" )
        ret = ret.select{|p| p.login_name =~ /^#{session.owner.login_name}(_|$)/}
      end
      dputs( 3 ){ "Result for #{f} is: #{ret.collect{|r| r.login_name}}" }
      ret
    }.flatten.uniq.sort{|a,b|
      a.login_name <=> b.login_name
    }
    dputs( 3 ){ "Result is: #{result.collect{|r| r.login_name}}" }
    not result and result = []
    if result.length > 20
      result = result[0..19]
    end

    # Check if we have an exact match on the login_name
    if exact = Persons.match_by_login_name( s )
      dputs( 3 ){"Found exact match"}
      if pos = result.index( exact )
        dputs( 3 ){"Found exact match at position #{pos}"}
        result[0], result[pos] = result[pos], result[0]
      end
    end
    ret = reply( :empty, [:persons] ) +
      reply( :update, { :persons => result.collect{|p|
          p.to_list
        }, :search => s })

    if result.length > 0 and do_list_choice
      ret += reply( :update, :persons => [ result[0].login_name ])
    end

    ret + reply( :focus, :search )
  end

  def rpc_autofill( session, args )
    ret = []
    if args['persons'] and args['persons'].length > 0
      p = Persons.match_by_login_name(args['persons'][0])
      if args['search']
        ret += rpc_callback_search( session, args, false )
      else
        ret += reply( :update, :persons => [ p.to_list ] ) +
          reply( :update, :search => p.login_name )
      end
      ret += reply( :update, :persons => [p.login_name] )
    elsif args['search']
      ret += rpc_callback_search( session, args )
    end
    ret
  end
end
