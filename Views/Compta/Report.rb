class ComptaReport < View
  def layout
    @visible = true
    @count = 1
    @rpc_update = true
    @order = 30
    
    gui_hboxg do
      gui_vboxg :nogroup do
        show_entity_account :account_list, 'Accounts', 'path', 
          :width => 400, :flex => 1
      end
      gui_vbox :nogroup do
        show_int :total
        show_str :desc, :width => 300
        show_button :report_movements
      end
      gui_window :get_report do
        show_html :txt
        show_button :close
      end
    end
    
  end
  
  def rpc_button_report_movements( session, data )
    if acc = data._account_list
      dputs(3){"Got account #{acc.path}"}
      file = "/tmp/report_movs_#{@count += 1}.pdf"
      acc.print_pdf( file, true )
      reply( :window_show, :get_report ) +
        reply( :update, :txt => "Get the report:<br>" +
          "<a href='#{file}' target='other'>#{file}</a>")
    end
  end
  
  def rpc_button_close( session, data )
    reply( :window_hide )
  end
end
