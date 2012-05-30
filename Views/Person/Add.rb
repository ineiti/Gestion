# Allows to add, modify and delete persons

class PersonAdd < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 50
    #@auto_update = 1

    gui_vbox do
      show_str :complete_name, :callback => :login
      show_block :address
      show_arg :first_name, :hidden => true
      show_arg :family_name, :hidden => true
      show_str :login_prop
      show_button :add_user, :clear
      gui_window :new_user do
        show_html :msg
        #show_str_ro :new_login
        #show_str_ro :new_pass
        show_button :modify, :print_student
      end
    end
  end

  def rpc_button_add_user( session, data )
    data.to_sym!
    dputs 0, "Pressed button accept with #{data.inspect}"
    if data[:login_prop]
      data[:login_name] = data[:login_prop]
      person = Persons.create( data )
      reply( 'update', get_form_data( person ) ) +
      reply( 'window_show', 'new_user') +
      reply( 'update', { :msg => "<h1>New user</h1>"+
        "<table border='1'><tr><td>Login</td><td>#{person.login_name}</td></tr>"+
      "<tr><td>Password</td><td>#{person.password_plain}</td></tr></table>",
      :login_prop => person.login_name } )
    end
  end

  def rpc_button_print_student( session, data )
    student = Persons.find_by_login_name( data['login_prop'] )
    dputs 1, "Printing student #{student.full_name}"
    student.print
    rpc_button_OK( session, data )
  end

  def rpc_button_OK( session, data )
    reply( :empty ) +
    reply( :window_hide ) +
    #reply( :init_values, [ :PersonTabs, { :search => data['login_prop'], :persons => [] } ] ) +
    reply( :switch_tab, :PersonModify ) +
    reply( :parent, View.PersonTabs.rpc_callback_search( session, 
      "search" => data['login_prop']) )
  end

  def rpc_update( session )
    reply( 'empty' )
  end

  def rpc_callback_login( session, data )
    dputs 3, "Got values: #{data.inspect}"
    complete_name = data['complete_name'] || ""
    if complete_name.length > 0
      reply( "update", {:login_prop => Persons.create_login_name( complete_name )})
    end
  end
end
