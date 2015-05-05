class SpecialPlug < View
  include VTListPane

  def layout
    @order = 150
    set_data_class :Plugs

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :plugs, :center_name
        show_button :delete, :new
      end
      gui_vbox :nogroup do
        show_block :default
        show_arg :internal_id, :width => 200
        show_button :save
      end
      gui_vbox :nogroup do
        show_text :stats
      end
    end
  end
end