class InternetEditClasses < View
  include VTListPane

  def layout
    set_data_class :InternetClasses
    @order = 100

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :classes, :name
        show_button :new, :delete
      end
      gui_vbox :nogroup do
        show_block :default
        show_button :save
      end
    end
  end
end