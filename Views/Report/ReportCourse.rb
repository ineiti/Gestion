# Allows for adding cash to a specific course

class ReportCourse < View
  include PrintButton
  
  def layout
    @order = 10
    @update = true
    @functions_need = [:cashbox, :accounting]

    gui_hboxg do
      gui_vboxg :nogroup do
        show_entity_course :course, :single, :name, 
          lambda{|c| c.entries}, :callback => true, :flexheight => 1
        show_print :print
      end
      gui_vbox :nogroup do
        show_table :report, :headings => [ :Date, :Desc, :Amount, :Rest ],
          :widths => [ 100, 200, 75, 75 ], :height => 400, :width => 470,
          :columns => [0, 0, :align_right, :align_right]
      end
      
      window_print_status
    end
  end
  
  def rpc_update( session )
    super( session ) +
      reply( :empty_nonlists, :course ) +
      reply( :update, :course => Courses.list_courses_entries(session) ) +
      reply_print( session )
  end
  
  def rpc_button_print( session, data )
    send_printer_reply( session, :print, data,
      data._course.report_pdf )
  end
  
  def rpc_list_choice_course( session, data )
    dputs(3){"report is #{data._report_start.inspect}"}
    ret = reply( :empty, :report )
    
    if data._course != []
      ret += reply( :update, :report => data._course.report_list )
    end
  end
end
