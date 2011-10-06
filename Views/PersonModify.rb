# Allows to add, modify and delete persons

class PersonModify < View
  def layout
    set_data_class :Persons
    @update = true

    gui_hbox do
      gui_vbox do
        gui_fields do
          show_find :login_name
          show_find :person_id
          show_block :address
        end
        show_button :save
      end

      gui_vbox :nogroup do
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
      when "save"
        # "internet_none" only reflects chosen entries, not the available ones per se!
        data.delete("internet_none")
        rep = reply( 'update', @data_class.save_data( data ) )
      end
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
