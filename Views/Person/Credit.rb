class PersonCredit < View
  def layout
    set_data_class :Persons
    @order = 15
    @update = true

    gui_vbox do
      show_int :credit_add
      show_str_ro :login_name
      show_int_ro :credit
      show_button :add_credit
			
      show_int_ro :your_credit_due
    end
  end
	
  def rpc_button_add_credit( session, data )
    dputs(3){"Adding credit"}
    rep = []
    if person = Persons.add_cash( session, data )
      rep = reply( :update, :credit_add => "" ) +
        reply( :update, :credit => person.credit )
    end
    rep + rpc_update( session )
  end
	
  def update( session )
    if person = session.owner
      {:your_credit_due => person.credit_due }
    end
  end

  def rpc_update( session )
    super( session ) +
      reply( :parent, reply( :focus, :search ) )
  end

  def rpc_list_choice( session, name, data )
    if name == "persons"
      dputs( 2 ){ "Got data: #{data.inspect}" }
      if data['persons'][0] and p = Persons.find_by_login_name( data['persons'].flatten[0])
        reply( :empty ) + reply( :update, p ) + reply( :update, update( session ) ) +
          reply( :focus, :credit_add )
      end
    end
  end
end