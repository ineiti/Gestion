class PersonTabs < View
  def layout
    @order = 10
    @update = true
    @persons_total = Persons.data.count

    gui_vbox :nogroup do
      show_str :search
      show_list_single :persons, '[]', :flexheight => 1, :callback => true
      show_button :start_search, :delete, :add

      gui_window :add_person do
        show_str :complete_name, :width => 150
        show_str :login_prop
        show_button :add_person, :close
      end
      
      gui_window :error do
        show_html :info
        show_button :close
      end
    end
  end
  
  def rpc_update( session )
    super( session )
  end
	
  def rpc_button_start_search( session, args )
    rpc_callback_search( session, args )
  end
  
  def rpc_button_delete( session, args )
    if session.can_view( :FlagDeletePerson )
      if ( p_login = args["persons"] ) and 
          ( p = Persons.match_by_login_name( p_login[0] ) )
        dputs(3){"Found person #{p.inspect} - #{p.class.name}"}
        begin
          p.delete
        rescue IsNecessary => who
          return reply( :window_show, :error ) +
            reply( :update, :info => "Course #{who.for_course.name} " +
              "still needs #{p.login_name}")
        end
        rpc_callback_search( session, args )
      end
    end
  end
  
  def rpc_update_view( session, args = nil )
    login_prop = session.can_view( :FlagAdminLoginProp ) ? :unhide : :hide
    super( session, args ) +
      reply( :focus, :search ) +
      reply( session.can_view( :FlagPersonDelete ) ? :unhide : :hide, :delete ) +
      reply( session.can_view( :FlagPersonAdd ) ? :unhide : :hide, :add ) +
      reply( login_prop, :login_prop ) +
      reply( :fade_in, :parent )
  end
  
  def rpc_list_choice( session, name, args )
    dputs( 2 ){ "args is #{args.inspect}" }
    dputs( 2 ){ "New choice #{name} - #{args['persons']}" }

    if name == 'persons' and args and args['persons']
      reply( :pass_tabs, [ "list_choice", name, { :persons => [ args['persons'] ] } ] ) +
        reply( :fade_in, :parent_child )
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
        permissions person_id email phone groups ).collect{|f|
      ret = Entities.Persons.search_by( f, s )
      if session.owner.permissions.index( "center" )
        ret = ret.select{|p| p.login_name =~ /^#{session.owner.login_name}(_|$)/}
      end
      dputs( 3 ){ "Result for #{f} is: #{ret.collect{|r| r.login_name}}" }
      ret
    }.flatten.uniq.sort{|a,b|
      a.login_name.to_s <=> b.login_name.to_s
    }
    dputs( 3 ){ "Result is: #{result.collect{|r| r.login_name}}" }
    not result and result = []

    # Check if we have an exact match on the login_name
    dputs(3){"Searching for exact match #{s}"}
    if exact = Persons.match_by_login_name( s )
      dputs( 3 ){"Found exact match"}
      if pos = result.index( exact )
        dputs( 3 ){"Found exact match at position #{pos}"}
        result.delete_at( pos )
        result.unshift( exact )
        dputs(3){"result is now #{result.inspect}"}
      end
    end

    if result.length > 20
      result = result[0..19]
    end

    ret = reply( :empty, [:persons] ) +
      reply( :update, { :persons => result.collect{|p|
          p.to_list
        }, :search => s })

    if result.length > 0 
      if do_list_choice
        ret += reply( :update, :persons => [ result[0].login_name ])
      end
    else
      ret += reply( :fade_in, :parent ) +
        reply( :child, reply( :empty ))
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

  def rpc_button_close( session, data )
    reply( :window_hide )
  end
  
  def rpc_button_add( session, data )
    reply( :window_show, :add_person ) +
      reply( :empty_only, [ :complete_name, :login_prop ] )
  end
  
  def rpc_button_add_person( session, data )
    data.to_sym!
    dputs( 3 ){ "Pressed button accept with #{data.inspect}" }
    person = Persons.create_person( data._complete_name, session.owner,
      data._login_prop )

    reply( :window_hide ) +
      rpc_callback_search( session, "search" => person.login_name)
    #reply( :child, reply( :switch_tab, :PersonModify ) ) +
  end

end
