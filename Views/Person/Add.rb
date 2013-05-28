# Allows to add, modify and delete persons

class PersonAdd < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 50
    #@auto_update = 1

    gui_vbox do
      show_str :complete_name, :callback => :login, :width => 150
      show_block :address
      show_arg :first_name, :hidden => true
      show_arg :family_name, :hidden => true
      show_str :login_prop
      show_button :add_user, :clear
    end
  end

  def rpc_button_add_user( session, data )
    data.to_sym!
    dputs( 3 ){ "Pressed button accept with #{data.inspect}" }
    if data[:login_prop]
      data[:login_name] = data[:login_prop]
      perms = ["internet"]
      if session.owner.permissions.index( "center" )
        data.merge!( {:login_name_prefix => "#{session.owner.login_name}_"} )
        perms.push( "teacher" )
      end
      person = Persons.create( data )
      person.permissions = perms
      reply( :empty ) +
        reply( :switch_tab, :PersonModify ) +
        reply( :parent, View.PersonTabs.rpc_callback_search( session,
          "search" => person.login_name) )
    end
  end

  def rpc_update( session )
    reply( 'empty' )
  end

  def rpc_callback_login( session, data )
    dputs( 3 ){ "Got values: #{data.inspect}" }
    complete_name = data['complete_name'] || ""
    if complete_name.length > 0
      reply( "update", {:login_prop => Persons.create_login_name( complete_name )})
    end
  end
end
