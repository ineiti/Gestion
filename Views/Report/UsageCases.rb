class ReportUsageCases < View
  include VTListPane

  def layout
    @order = 50
    @update = true

    set_data_class :Usages

    gui_vboxg do
      gui_hboxg :nogroup do
        gui_vbox :nogroup do
          vtlp_list :usage_list, 'name'
          #show_entity_usage :usage, :single, :name, :callback => true,
          #                  :flexheight => 1
          show_button :delete, :new
        end
        gui_vboxg :nogroup do
          show_str :name
          show_str :file_dir
          show_str :file_glob
          show_text :file_filter, :flexwidth => 10, :flexheight => 1
          show_button :save
        end
      end
      gui_vboxg :nogroup do
        show_list_drop :file_choice, '%w(none)', :callback => :file_chosen
        show_text :file_source, :flexwidth => 10, :flexheight => 1
        show_text :file_filtered, :flexheight => 1
      end
    end
  end

  def rpc_update(session)
    reply(:empty, :file_choice) +
        if ul = Usages.match_by_id(session.s_data._usage_list)
          dp ul.name
          reply(:update, :file_choice => ul.fetch_files)
        else
          []
        end
  end
end