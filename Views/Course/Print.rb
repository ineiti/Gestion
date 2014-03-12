# Prints the students of a course

class CoursePrint < View
  include PrintButton
  
  def layout
    @visible = true
    @order = 100
    @update = true
    
    gui_vbox do
      gui_vbox do
        show_print :print_presence
        show_print :print_exa_1
        show_print :print_exa_2
        show_print :print_exa_3
      end
      gui_window :missing_data do
        show_html :missing
        show_button :close
      end
      gui_window :printing do
        show_html :msg_print
        show_button :close
      end
    end
  end
  
  def rpc_update( session )
    super( session ) +
      reply_print( session )
  end
  
  def rpc_button_print_presence( session, data )
    dputs(3){"printing"}
    ret = rpc_print( session, :presence, data )
    lp_cmd = cmd_printer( session, :presence )
    if data['name'] and data['name'].length > 0
      case rep = Courses.match_by_name( data['name'] ).print_presence( lp_cmd )
      when true
        ret + reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression - de la fiche de présence pour<br>#{data['name']} en cours" )
      when false
        ret + reply( "window_show", "missing_data" ) +
          reply( "update", :missing => "One of the following is missing:<ul><li>date</li><li>students</li><li>teacher</li></ul>" )
      else
        ret + reply( "window_show", "missing_data" ) +
          reply( "update", :missing => "Click on the link: <a target='other' href=\"#{rep}\">PDF</a>" )
      end
    end
  end
  
  def print_exa( session, data, number )
    dputs(3){"printing with #{data['courses'].inspect}"}
    exa = "exa_#{number}".to_sym
    lp_cmd = cmd_printer( session, exa )
    ret = rpc_print( session, exa, data )
    if data['courses'] and data['courses'].length > 0
      case rep = Courses.match_by_course_id( data['courses'][0] ).print_exa( lp_cmd, number )
      when true
        ret += reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression de la fiche d'évaluation pour<br>#{data['name']} en cours" )
      when false
        ret += reply( :window_show, :missing_data ) +
          reply( :update, :missing => "One of the following is missing:<ul><li>date</li><li>students</li><li>teacher</li></ul>" )
      else
        ret += reply( :window_show, :missing_data ) +
          reply( :update, :missing => "Click on the link: <a target='other' href=\"#{rep}\">PDF</a>" )
      end
    end
    return ret
  end
  
  def rpc_button_print_exa_1( session, data )
    print_exa( session, data, 1 )
  end
  def rpc_button_print_exa_2( session, data )
    print_exa( session, data, 2 )
  end
  def rpc_button_print_exa_3( session, data )
    print_exa( session, data, 3 )
  end

  def rpc_button_close( session, data )
    reply( :window_hide )
  end

end
