# To change this template, choose Tools | Templates
# and open the template in the editor.

class AdminCourseTypeProfeda < View
  include VTListPane
  
  def layout
    set_data_class :CourseTypes
    @visible = false
    
    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :ctype, :profeda_code
        show_button :new, :delete
      end
      
      gui_vbox :nogroup do
        show_block :profeda
        
        show_block_ro :strings, :width => 200
      end
      
      gui_window :add_profeda do
        show_html :txt, "Please enter the ID for<br>this course"
        show_str :profeda_id
        show_button :fetch_course
      end
    end
  end
  
  def rpc_button_new( session, data )
    super( session, data ) + reply( :window_show, :add_profeda )
  end
  
  def rpc_button_fetch_course( session, data )
    session.s_data.merge!( :fetch => 1 )
    reply( :update, :txt => "Going to fetch course" ) +
      reply( :auto_update, -2 ) +
      reply( :window_show, :add_profeda )
  end
  
  def rpc_update_with_values( session, data )
    if ( session.s_data[:fetch] -= 1 ) == 0
      pc = data['profeda_id']
      ct = CourseTypes.create( :profeda_code => pc.reverse, :name => pc )
      reply( :window_hide ) + reply( :auto_update, 0 ) +
        vtlp_update_list( session )
      #+ reply( :parent, rpc_list_choice( session,
      #  "ctype", "ctype" => [ct.coursetype_id]))
    else
      reply( :update, :txt => "Wait is #{session.s_data[:fetch]}") +
        reply( :window_show, :add_profeda )
    end
  end
end
