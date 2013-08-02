class CourseResponsible < View
  include VTListPane

  def layout
    set_data_class :Persons
    @update = true
    @visible = false
    @order = 100

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :persons, 'login_name', 'listp_responsible'
        show_button :new, :delete, :save
      end
      gui_vbox :nogroup do
        show_block :address
      end
    end
  end
  
  def rpc_button_save( session, data )
    field = vtlp_get_entity( data )
    dputs( 2 ){ "Field is #{field.inspect}, setting data #{data.inspect}" }
    selection = data[@vtlp_field][0]
    if field
      field.data_set_hash( data.to_sym )
    else
      if data["family_name"] or data["first_name"]
        resp = Persons.create( data.to_sym.merge(
            {:login_name_prefix => "#{session.owner.login_name}_"} ) )
        resp.permissions = %w( internet teacher )
        selection = resp.id
      end
    end
    dputs(3){"vtlp_method is #{@vtlp_method} - selection is #{selection.inspect}"}
    vtlp_update_list( session, selection )
    #      [data[@vtlp_field][0], field.data_get(@vtlp_method)] )
  end
  
  def rpc_update( session )
    reply( :empty, [:persons] ) +
      reply( :update, :persons => Persons.listp_responsible( session ) )
  end
end
