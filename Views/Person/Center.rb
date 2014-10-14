# Some special, restricted administration-things for a center-director

class PersonCenter < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 40

    gui_vbox do
      gui_hbox :nogroup do
        show_str_ro :login_name
        show_str_ro :person_id
        show_field :role_diploma
        show_list :permissions, "%w( teacher center_director )"
        show_button :save
      end
    end
  end
  
  def reply_person( p )
    reply( :empty_fields, [:permissions] ) +
      reply( :update, :permissions => %w( teacher center_director ) ) +
      reply( :update, :login_name => p.login_name, :person_id => p.person_id,
      :role_diploma => p.role_diploma, 
      :permissions => p.permissions & %w( teacher center_director ) )
  end

  def rpc_button_save( session, data )
    person = Persons.match_by_person_id( data['person_id'] )
    if person
      log_msg :persons, "#{session.owner.login_name} saves #{data.inspect}"
      person.role_diploma = data._role_diploma
      person.permissions = person.permissions - %w( teacher center_director ) +
        data._permissions
      reply_person( person )
    end
  end

  def rpc_list_choice( session, name, data )
    if name == "persons"
      dputs( 2 ){ "Got data: #{data.inspect}" }
      if p = Persons.match_by_login_name( data['persons'].flatten[0])
        reply_person( p )
      end
    end
  end
end
