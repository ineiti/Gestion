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
        show_str :new_password
        show_str_ro :password_plain
        show_button :change_password
      end

      gui_window :printing do
        show_html :msg_print
        show_button :close
      end

    end
  end

  def rpc_button( session, name, data )
    dputs( 2 ){ "Pressed button #{name} with #{data.inspect}" }
    person = Persons.find_by_person_id( data['person_id'] )
    rep = [] #reply( 'empty' )
    if person
      case name
      when "change_password"
        person.password = data['new_password']
      when "save"
        # "internet_none" only reflects chosen entries, not the available ones per se!
        data.delete("internet_none")
        rep = reply( 'update', Persons.save_data( data ) )
      when "print_student"
        file = person.print
        if file.class == String
          rep = reply( :window_show, :printing ) +
						reply( :update, :msg_print => "Click to download:<ul>" +
							"<li><a href=\"#{file}\">#{file}</a></li></ul>" )
        end
      when "close"
        rep = reply( :window_hide )
      end
#      reply( 'update', get_form_data( person ) )
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
      dputs( 2 ){ "Got data: #{data.inspect}" }
      if data['persons'][0] and p = Persons.find_by_login_name( data['persons'].flatten[0])
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
