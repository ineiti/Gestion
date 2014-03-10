class ComptaShow < View
  include VTListPane
  def layout
    @visible = true
    @count = 1
    
    if Module.constants.index :ACQooxView
      set_data_class :Accounts
    end
    gui_hbox do
      gui_vbox do
        vtlp_list_entity :account_list, 'Accounts', 'path', 
          :width => 300, :maxheight => 250
      end
      gui_vbox do
        show_int :total
        show_button :report_movements
      end
    end
    gui_window :get_report do
      show_html :txt
      show_button :close
    end
    
  end
  
  def rpc_button_report_movements( session, data )
    if acc = data._account_list
      ddputs(3){"Got account #{acc.path}"}
      file = "/tmp/report_movs_#{@count += 1}.pdf"
      acc.print_account( file, true )
      reply( :show_window, :get_report ) +
        reply( :update, :txt => "Get the report:<br>" +
        "<a href='/tmp/#{file}'>#{file}</a>")
    end
  end
end
