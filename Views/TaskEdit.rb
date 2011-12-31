class TaskEdit < View
  include VTListPane
  
  def layout
    set_data_class :Tasks
    @update = true
    
    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :tasks, "tasks"
        show_button :delete
      end
      gui_vbox :nogroup do
        show_list_drop :client, "Entities.Clients.list_name"
        show_list_drop :person, "Entities.Workers.list_full_name"
        show_block :work
        show_block :other
        
        show_button :save, :new
      end
    end
  end
  
  def rpc_update( session )
    vtlp_update_list
  end
  
  def rpc_button_save( session, data )
    if data['date']
      super( session, data )
    end
  end
end
