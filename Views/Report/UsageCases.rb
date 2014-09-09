class ReportUsageCases < View
  include VTListPane

  def layout
    @order = 50
    @update = true
    @functions_needed = [ :usage_report ]

    set_data_class :Usages

    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          vtlp_list :usage_list, 'name'
          #show_entity_usage :usage, :single, :name, :callback => true,
          #                  :flexheight => 1
          show_button :delete, :new
        end
        gui_vbox :nogroup do
          show_str :name
          show_str :file_dir
          show_str :file_glob
          show_text :file_filter, :flexwidth => 10, :flexheight => 1
          show_button :save
        end
      end
      gui_vboxg :nogroup do
        show_list_drop :file_data, '%w(none)', :callback => :file_chosen
        show_text :file_source, :flexwidth => 10, :flexheight => 1
        show_text :file_filtered, :flexwidth => 10, :flexheight => 10
      end
    end
  end
  
  def rpc_list_choice_file_data( session, data )
    file_data = data._file_data.first
    return if file_data == 'none'
    usage_list = Usages.match_by_id( data._usage_list.first ) or return
    file_f = [{}]
    file_s = if File.exists? file_data
               file_f = usage_list.filter_file( file_data )
               File.open( file_data, 'r').readlines[0..100]
             else
               ''
             end
    reply( :empty_only, %w( file_source file_filtered ) ) +
        reply( :update, :file_source => file_s ) +
        reply( :update, :file_filtered => file_f[0..100].join("\n"))
  end

  def rpc_update(session)
    reply(:empty_only, :file_data) +
        if ul = Usages.match_by_id(session.s_data._usage_list)
          reply(:update, :file_data => ul.fetch_files)
        else
          []
        end
  end
end