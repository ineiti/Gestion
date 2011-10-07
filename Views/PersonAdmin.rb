# Allows to add, modify and delete persons

class PersonAdmin < View
  def layout
    set_data_class :Persons
    @update = true
    
    gui_vbox do
      gui_group do
        gui_hbox :nogroup do
          gui_hbox :nogroup do
            gui_fields do
              show_find :login_name
              show_find :person_id
              show_block :address
            end
            gui_fields do
              show_block :admin
            end
          end
          gui_vbox :nogroup do
            gui_fields do
              show_field :groups
              show_field :internet_none
              show_fromto :internet_block
              show_button :add_block, :del_block
            end          
          end
        end
        show_button :save
      end
      
      gui_hbox :nogroup do
        show_int_ro :credit
        show_int :credit_add
        show_int_ro :your_credit_due
        show_button :add_credit
        
        show_str :new_password
        show_str :password_plain
        show_button :change_password
      end
    end
  end
  
  def rpc_button( sid, name, data )
    dputs 0, "Pressed button #{name} with #{data.inspect}"
    person = @data_class.find_by_person_id( data['person_id'] )
    rep = reply( 'empty' )
    if person
      case name
      when "change_password"
        person.password = data['new_password'] 
      when "add_credit"
        @data_class.add_cash( sid, data )
        rep = reply( 'update', {:credit_add => ""})
      when "add_block"
        if not person.internet_none
          dputs 4, "Adding internet_none"
          person.internet_none = []
        end
        dputs 2, "Internet_none: #{person.internet_none.inspect}"
        time = data['internet_block'].join(";")
        if not person.internet_none.index( time )
          person.internet_none += [ time ]
        end
      when "del_block"
        dputs 3, "Deleting block: #{data['internet_none']}"
        if person and del = data['internet_none']
          person.internet_none -= del
        end
      when "save"
        # "internet_none" only reflects chosen entries, not the available ones per se!
        data.delete("internet_none")
        rep = reply( 'update', @data_class.save_data( data ) )
      end
      rep += reply( 'empty', [:internet_none]) +
      reply( 'update', get_form_data( person ) )
    end
    rep + rpc_update( sid )
  end
  
  def rpc_find( sid, field, data )
    rep = @data_class.find( field, data )
    if not rep
      rep = { "#{field}" => data }
    end
    update_layout +
    reply( 'update', rep ) + rpc_update( sid )
  end
  
  def update( sid )
    {:your_credit_due => @data_class.find_by_session_id( sid ).credit_due }
  end
end
