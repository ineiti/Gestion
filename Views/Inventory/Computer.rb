class InventoryComputer < View
  include VTListPane
  def layout
    set_data_class :Computers
    
    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :computer_list, 'name_service', :width => 100
        show_button :new, :delete
      end

      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_block :identity, :width => 150
          show_block :performance
          show_button :save
        end
        gui_vbox :nogroup do
          show_block :ticket
        end
      end
    end
  end
end
