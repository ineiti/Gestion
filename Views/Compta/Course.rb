# Allow for courses to be paid
# Can search by courses or by students

class ComptaCourse < View
  def layout
    @order = 0
    @functions_need = [:accounting_courses]
    
    gui_hbox do
      gui_vbox do
        show_list_single :courses, :flexheight => 1, :callback => true, 
          :width => 100
      end
      gui_vbox do
        show_str :account_path, :width => 200
        show_button :new_account_path
      end
    end
    
    gui_window :win_new_account do
      show_list_single :new_account
      show_button :assign_new_account
    end
  end
  
  def rpc_button_new_account_path( session, *args )
    reply( :update, { :new_account => [[1, "hi"]]})
    reply( :window_show, :win_new_account )
  end
  
  def rcp_button_assign_new_account( session, *args )
    reply( :window_hide )
  end
end
