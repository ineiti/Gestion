class Report < View
  def layout
    gui_hbox do
      gui_vbox do
        show_list_single :report_type, "View.Report.list_types", :callback => true
        show_date :start
        show_date :end
      end
      gui_vbox do
        
      end
    end
  end
  
  def list_types
    [[1,"Balance"],[2,"Accounts"]]
  end
  
  def rpc_list_choice( session, name, args )
    dputs 0, "args is #{args}"
    case args[:report_type][0]
    when 1
    when 2
    end
  end
end