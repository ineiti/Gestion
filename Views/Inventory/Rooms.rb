class InventoryRoom < View
  include VTListPane
  def layout
    set_data_class :Rooms
    
    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :rooms, 'name'
        show_button :new, :save, :delete
      end

      gui_vbox :nogroup do
        show_block :all
      end
    end
  end
end