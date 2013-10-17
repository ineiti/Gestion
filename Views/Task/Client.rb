class TaskClient < View
  include VTListPane
  
  def layout
    set_data_class :Clients
    
    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :clients, 'name'
        show_button :delete
      end
      gui_vbox :nogroup do
        #show_find :name
        show_block :prices
        show_block :address
        show_block :contact
        show_button :new, :save
      end
    end
  end
end
