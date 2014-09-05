class ReportUsageCases < View

  def layout
    @order = 50

    gui_hbox do
      gui_vbox :nogroup do
        show_entity_usage :usage, :single, :name, :callback => true,
                          :flexheight => 1
        show_button :usage_add, :usage_del
      end
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_str :file_dir, :width => 400
          show_str :file_glob
          show_text :file_filter
        end
        gui_vbox :nogroup do
          show_list_drop :file_choice, :callback => true
          show_text :file_source, :width => 400
          show_text :file_filtered, :width => 400
        end
      end
    end
  end
end