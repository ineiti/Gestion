class TaskWorker < View
  include VTListPane
  
  def layout
    set_data_class :Workers
    
    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :workers, "login_name"
        show_button :delete
      end
      gui_vbox :nogroup do
        #show_find :login_name
        #show_find :person_id
        show_block :work
        
        show_button :new, :save
      end
    end
  end
  
  # Standard search-field action to take
  def rpc_find( session, field, data )
    rep = Entities.Persons.find( field, data )
    if not rep
      rep = { "#{field}" => data }
    end
    reply( :update, rep ) + rpc_update( session )
  end
end
