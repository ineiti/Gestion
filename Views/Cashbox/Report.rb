# Allows for adding cash to a specific course

class CashboxReport < View
  include PrintButton
  
  def layout
    @order = 30
    @update = true
    @functions_need = [:cashbox]
    
    gui_hbox do
      gui_vbox :nogroup do
        show_list_single :report_type, :callback => true, :maxheight => 160
        show_date :report_start, :callback => :date
        show_entity_course_lazy :course, :single, :name, 
          lambda{|c| c.entries}, :callback => true, :flexheight => 1
        show_print :print
      end
      gui_vbox :nogroup do
        show_table :report, :headings => [ :Date, :Desc, :Amount, :Sum ],
          :widths => [ 100, 200, 75, 75 ], :height => 400, :width => 470,
          :columns => [0, 0, :align_right, :align_right]
        show_button :delete
      end
      
      gui_window :print_status do
        gui_vbox :nogroup do
          show_html :status
          show_button :close
        end
      end
    end
  end
  
  def rpc_show( session )
    super( session )
  end
  
  def rpc_update( session )
    super( session ) +
      reply( :empty_fields, [ :course, :report_type ] ) +
      reply( :update, :report_type => 
        %w( Course Due_Daily Due_All Paid_All ).
        map.with_index{|d,i|
        [ i + 1, d ]} ) +
      reply( :update, :course => Courses.list_courses_entries(session) ) +
      reply( :hide, [:report_start, :course ] ) +
      reply( :update, :report_start => Date.today.strftime( "%d.%m.%Y") ) +
      reply_visible( session.owner.has_permission?( :accounting ), :delete ) +
      reply_print( session )
  end
  
  def rpc_button_print( session, data )
    ret = rpc_print( session, :print, data )
    if data._report_type == []
      return ret
    end
    date = Date.parse( data._report_start )
    
    if ( report = data._report_type.first ) > 1
      file = session.owner.report_pdf( 
        [ :daily, :all, :all_paid ][report - 2], date )
    else
      file = data._course.report_pdf
    end
    
    if printer = send_printer( session, :print, file )
      ret + reply( :window_show, :print_status ) +
        reply( :update, :status => "Printed to #{printer}")
    else
      ret + reply( :window_show, :print_status ) +
        reply( :update, :status => "<a href='#{file}' target='other'>#{file}</a>")
    end
  end
  
  def rpc_list_choice_report_type( session, data )
    dputs(3){"report is #{data._report_start.inspect}"}
    date = Date.parse( data._report_start.to_s )
    ret = reply( :empty, :report )
    
    case report = data._report_type.first
    when 1
      if data._course != []
        ret += reply( :update, :report => data._course.report_list )
      end
      show = :course
    when 2..4
      ret += reply( :update, :report => 
          session.owner.report_list(
          [ :daily, :all, :all_paid ][report - 2], date ) )
      show = :report_start
    end
    
    ret + reply( :unhide, show ) +
      reply( :hide, show == :report_start ? :course : :report_start )
  end
  
  def rpc_list_choice_course( session, data )
    rpc_list_choice_report_type( session, data )
  end
  
  def rpc_callback_date( session, data )
    rpc_list_choice_report_type( session, data )
  end
  
  def rpc_button_delete( session, data )
    if ( gid = data._report.first ).to_s.length > 0
      if mov = Movements.match_by_global_id( gid )
        log_msg "cashbox_report", "Deleting movement #{mov.inspect}"
        mov.delete
        rpc_list_choice_report_type( session, data )
      end
    end
  end
end
