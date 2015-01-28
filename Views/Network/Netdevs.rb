class NetworkNetdevs < View
  include VTListPane

  def layout
    @order = 200
    @functions_need = [:network_pro]

    set_data_class :Netdevs

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :netdevs, :name
        show_button :delete, :new
      end
      gui_vbox :nogroup do
        show_block :default
        show_button :save
      end
    end
  end
end