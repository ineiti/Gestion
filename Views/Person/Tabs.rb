class PersonTabs < View
  def layout
    @order = 10
    @update = true

    gui_vboxg :nogroup do
      show_list_single :persons, "[]", :callback => true
      show_str :search, :callback => :search
    end
  end
  
  def rpc_update_view( session, args = nil )
    super( session, args ) +
    reply( :focus, :search )
  end
  
  def rpc_list_choice( session, name, args )
    dputs 2, "args is #{args.inspect}"
    dputs 2, "New choice #{name} - #{args['persons']}"

    if name == 'persons' and args and args['persons']
      reply( :pass_tabs, [ "list_choice", name, { :persons => [ args['persons'] ] } ] )
    else
    []
    end
  end

  def rpc_callback_search( session, data, do_list_choice = true )
    dputs 2, "Got data: #{data.inspect}"

    s = data['search']
    result = %w( login_name family_name first_name person_id email phone ).collect{|f|
      ret = Entities.Persons.search_by( f, s )
      dputs 3, "Result for #{f} is: #{ret.collect{|r| r.login_name}}"
      ret
    }.flatten.uniq
    dputs 3, "Result is: #{result.collect{|r| r.login_name}}"
    not result and result = []

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
      p = Persons.find_by_login_name(args['persons'][0])
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