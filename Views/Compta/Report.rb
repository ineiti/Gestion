class ComptaReport < View
  def layout
    @visible = true
    @count = 1
    @rpc_update = true
    @order = 30
    
    gui_hboxg do
      gui_vboxg :nogroup do
        show_entity_account_lazy :account_list, :single, 
          :width => 400, :flex => 1, :callback => true
      end
      gui_vbox :nogroup do
        show_int :total
        show_str :desc, :width => 300
        show_button :account_update, :report_movements
      end
      gui_window :get_report do
        show_html :txt
        show_button :close
      end
    end
    
  end
  
  def rpc_button_report_movements( session, data )
    if acc = data._account_list
      ddputs(3){"Got account #{acc.path}"}
      file = "/tmp/report_movs_#{@count += 1}.pdf"
      acc.print_pdf( file, true )
      reply( :window_show, :get_report ) +
        reply( :update, :txt => "Get the report:<br>" +
          "<a href='#{file}' target='other'>#{file}</a>")
    end
  end
  
  def rpc_button_account_update( session, data )
    if ( acc = data._account_list ).class == Account
      acc.update_total
    end
  end
  
  def rpc_update_view( session )
    super( session ) +
      reply( :empty, :account_list ) +
      reply( :update, :account_list => AccountRoot.current.listp_path )
  end
  
  def rpc_list_choice_account_list( session, data )
    reply( :empty ) +
      if ( acc = data._account_list ) != []
        reply( :update, :total => acc.total_form ) +
          reply( :update, :desc => acc.desc )
      else
        []
      end
  end
end
