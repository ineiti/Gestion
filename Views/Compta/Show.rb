class ComptaShow < View
  include VTListPane
  def layout
    @visible = false
    
    if Module.constants.index :ACQooxView
      set_data_class :Accounts
    end
    gui_hbox do
      gui_vbox do
        vtlp_list :account_list, 'path', :width => 150, :maxheight => 250
      end
      gui_vbox do
        show_int :total
      end
    end
  end
end
