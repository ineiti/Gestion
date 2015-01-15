class PlugEdit < View
  include VTListPane

  def layout
    @order = 150
    set_data_class :Plugs

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :plugs, :internal_id
        show_button :delete, :new
      end
      gui_vbox :nogroup do
        show_block :default
        show_button :save
      end
    end
  end
end