# Allows to add, modify and delete persons

class PersonAdmin < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 30

    gui_vbox do
      gui_group do
        gui_hbox :nogroup do
          gui_hbox :nogroup do
            gui_fields do
              show_str_ro :login_name
              show_str_ro :person_id
              show_block :admin
              show_arg :permissions, :flexheight => 1
            end
          end
          gui_vbox :nogroup do
            gui_vbox :nogroup do
              show_field :groups
            end
=begin
            gui_vbox :nogroup do
              show_field :internet_none
              show_fromto :internet_block
              show_button :add_block, :del_block
            end
=end
          end
        end
        show_button :save
      end

    end
  end

  def rpc_button( session, name, data )
    dputs( 0 ){ "Pressed button #{name} with #{data.inspect}" }
    person = Persons.match_by_person_id( data['person_id'] )
    rep = reply( 'empty' )
    if person
      #rep += reply( 'empty', [:internet_none])
      case name
      when "add_block"
        if not person.internet_none
          dputs( 4 ){ "Adding internet_none" }
          person.internet_none = []
        end
        dputs( 2 ){ "Internet_none: #{person.internet_none.inspect}" }
        time = data['internet_block'].join(";")
        if not person.internet_none.index( time )
          person.internet_none += [ time ]
        end
      when "del_block"
        dputs( 3 ){ "Deleting block: #{data['internet_none']}" }
        if person and del = data['internet_none']
        person.internet_none -= del
        end
      when "save"
        # "internet_none" only reflects chosen entries, not the available ones per se!
        #       rep += reply( 'update', Persons.save_data( data ) )
        # data.delete("internet_none")
        Persons.save_data( data )
      end
      rep += update_form_data( person )
    end
    rep + rpc_update( session )
  end

  def rpc_find( session, field, data )
    rep = Persons.find( field, data )
    if not rep
      rep = { "#{field}" => data }
    end
    update_layout( session ) +
    reply( 'update', rep ) + rpc_update( session )
  end
  
  def rpc_list_choice( session, name, data )
    if name == "persons"
      dputs( 2 ){ "Got data: #{data.inspect}" }
      if p = Persons.match_by_login_name( data['persons'].flatten[0])
        #reply( :empty, [:internet_none] ) +
        reply( :empty, [:permissions] ) +
        reply( :update, :permissions => Permission.list.sort) +
        reply( :empty, [:groups] ) +
        reply( :update, :groups => eval( Persons.get_value( :groups ).list ) ) +
        reply( :update, p )
      end
    end
  end

  def update( session )
    {:your_account_total_due => session.owner.account_total_due }
  end
end
