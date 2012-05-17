class PersonTabs < View
  def layout
    @order = 10
    
    gui_vboxg :nogroup do
      show_list_single :persons, "[]", :callback => true
      show_str :search, :callback => :search
    end
  end

  def rpc_list_choice( session, name, args )
    dputs 2, "New choice #{name} - #{args.inspect}"

    reply( 'pass_tabs', [ "list_choice", name, args ] )
  end
  
  def rpc_callback_search( session, data )
    dputs 2, "Got data: #{data.inspect}"
    
    s = data['search']
    result = ( Entities.Persons.search_by_first_name( s ) +
      Entities.Persons.search_by_family_name( s ) +
      Entities.Persons.search_by_login_name( s ) ).uniq

    reply( :empty, [:persons] ) +
    reply( :update, { :persons => result.collect{|p|
      [p.login_name, "#{p.full_name} - #{p.login_name}:#{p.password_plain}"]
      }, :search => s }) +
    reply( :focus, :search )
  end
end