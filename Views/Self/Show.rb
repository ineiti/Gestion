# Allows to add, modify and delete persons

class SelfShow < View
  def layout
    set_data_class :Persons
    @order = 20
    
    gui_hbox do
      show_block :address
      show_button :save
      
      gui_vbox :nogroup do
        show_str :new_password
        show_button :change_password
        
        show_button :logout
      end
    end
    
    dputs 5, "#{@layout.inspect}"
  end
  
  def rpc_button( session, name, data )
    dputs 0, "Pressed button #{name} with #{data.inspect}"
    person = session.owner
    case name
      when "change_password"
      person.password = data['new_password']
      when "save"
      person.set_data( data )
      when "logout"
      return reply( 'reload' )
    end
    return nil
  end
  
  def rpc_show( session )
    super( session ) + [ { :cmd => "update", :data => update( session ) } ]
  end
end