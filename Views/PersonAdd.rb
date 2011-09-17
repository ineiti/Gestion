# Allows to add, modify and delete persons

class PersonAdd < View
  def layout
    set_data_class :Persons
    @update = true
    #@auto_update = 1
    
    gui_vbox do
      show_block :address
      show_arg :first_name, :callback => :login
      show_arg :family_name, :callback => :login
      show_str :login_prop
      show_button :add_user, :clear  
      gui_window :new_user do
        show_str_ro :msg
        show_str_ro :new_login
        show_str_ro :new_pass
        show_button :OK
      end
    end    
  end
  
  def rpc_button_add_user( sid, data )
    data.to_sym!
    dputs 0, "Pressed button accept with #{data.inspect}"
    if data[:login_prop]
      data[:login_name] = data[:login_prop]
      person = @data_class.create( data )
      reply( 'update', get_form_data( person ) ) +
      reply( 'window_show', 'new_user') +
      reply( 'update', {:new_login => person.login_name, :new_pass => person.password_plain,
      :msg => "New user:"})
    end
  end
  
  def rpc_button_OK( sid, data )
    reply( 'empty') +
    reply( 'window_hide')
  end
  
  def rpc_update( sid )
    reply( 'empty' )
  end
  
  def rpc_callback_login( sid, data )
    dputs 3, "Got values: #{data.inspect}"
    first = data['first_name'] || ""
    family = data['family_name'] || ""
    if first.length > 0 and family.length > 0
      reply( "update", {:login_prop => @data_class.create_login_name( first, family )})
    end
  end
end
