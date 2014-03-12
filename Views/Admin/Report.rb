class AdminReport < View
  def layout
    @visible = false
    @order = 30
    
    gui_hbox do
      gui_vbox do
        show_list_single :report_type, "View.AdminReport.list_types", :callback => true
        show_date :start
        show_date :end
      end
    end
  end
  
  def list_types
    [[1,"Balance"],[2,"Accounts"]]
  end
  
  def rpc_list_choice( session, name, args )
    if name == "report_type"
      dputs( 3 ){ "args is #{args.inspect}" }
      case args["report_type"][0]
      when 1
      when 2
      end
    end
  end
end
