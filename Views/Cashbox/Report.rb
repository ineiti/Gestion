# Allows for adding cash to a specific course

class CashboxReport < View
  include PrintButton
  
  def layout
    @order = 30
    @update = true
    
    gui_hbox do
      gui_vbox :nogroup do
        show_list_single :report_type, :callback => true, :maxheight => 100
        show_date :report_start, :callback => :date
        show_entity_course_lazy :course, :single, :name, 
          lambda{|c| c.entries}, :callback => true, :flexheight => 1
        show_print :print
      end
      gui_vbox :nogroup do
        show_table :report, :headings => [ :Date, :Desc, :Amount ],
          :widths => [ 100, 300, 100 ], :height => 400
      end
      
      gui_window :print_status do
        gui_vbox do
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
      reply( :empty, [ :course, :report_type ] ) +
      reply( :update, :report_type => 
        %w( Cash_Daily Cash_Weekly Cash_Monthly Cash_All
        Course ).map.with_index{|d,i|
        [ i + 1, d ]} ) +
      reply( :update, :course => Courses.list_courses_entries(session) ) +
      reply( :hide, [:report_start, :course ] ) +
      reply( :update, :report_start => Date.today.strftime( "%d.%m.%Y") ) +
      reply_print( session )
  end
  
  def rpc_button_print( session, data )
    ret = rpc_print( session, :print, data )
    if not session.owner.account_due or data._report_type == []
      return rpc_update( session )
    end
    date = Date.parse( data._report_start )
    
    if ( report = data._report_type.first ) < 5
      file = session.owner.report_pdf( report, date )
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
    if not session.owner.account_due
      return rpc_update( session )
    end
    ddputs(3){"report is #{data._report_start.inspect}"}
    date = Date.parse( data._report_start.to_s )
    ret = reply( :empty_only, :report )
    
    case report = data._report_type.first
    when 1..4
      ret += reply( :update, :report => 
          session.owner.report_list( report, date ) )
      show = :report_start
    when 5
      if data._course != []
        ret += reply( :update, :report => data._course.report_list )
      end
      show = :course
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
end