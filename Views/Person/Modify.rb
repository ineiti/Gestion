# Allows to add, modify and delete persons

class PersonModify < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 10

    gui_hbox do
      gui_vbox do
        gui_fields do
          show_str_ro :login_name, :width => 150
          show_str_ro :person_id
          show_block :address
        end
        show_button :save, :print_student
      end

      gui_vbox :nogroup do
        show_int_ro :credit
        show_int :credit_add
        show_int_ro :your_credit_due
        show_button :add_credit

        show_str :new_password
        show_str_ro :password_plain
        show_button :change_password
      end
    end
  end

  def rpc_button( session, name, data )
    dputs 2, "Pressed button #{name} with #{data.inspect}"
    person = Persons.find_by_person_id( data['person_id'] )
    rep = [] #reply( 'empty' )
    if person
      case name
      when "change_password"
        person.password = data['new_password']
      when "add_credit"
        Persons.add_cash( session, data )
        rep = reply( :update, :credit_add => "" ) +
        reply( :update, :credit => person.credit )
      when "save"
        # "internet_none" only reflects chosen entries, not the available ones per se!
        data.delete("internet_none")
        rep = reply( 'update', Persons.save_data( data ) )
      when "print_student"
        person.print
      end
      reply( 'update', get_form_data( person ) )
    end
    rep + rpc_update( session )
  end

  def rpc_find( session, field, data )
    rep = Persons.find( field, data )
    if not rep
      rep = { "#{field}" => data }
    end
    update_layout +
    reply( 'update', rep ) + rpc_update( session )
  end
  
  def rpc_list_choice( session, name, data )
    if name == "persons"
      dputs 2, "Got data: #{data.inspect}"
      if p = Persons.find_by_login_name( data['persons'][0][0])
        reply( :empty ) + reply( :update, p ) + reply( :update, update( session ) ) +
        reply( :focus, :credit_add )
      end
    end
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
end
