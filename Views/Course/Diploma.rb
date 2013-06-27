=begin
Shows the existing courses and the courses on the server, so that the
two can be synchronized.
=end


class CourseDiploma < View
  include PrintButton
  
  def layout
    set_data_class :Courses
    @order = 30
    @thread = nil

    gui_hbox do
      gui_vbox :nogroup do
        show_list :diplomas
      end
      gui_vbox :nogroup do
        show_button :do_diplomas
        show_print :print
      end
      gui_window :missing_data do
        show_html :missing
        show_button :close
      end
      gui_window :printing do
        show_html :msg_print
        show_button :close
      end    
      gui_window :create_diplomas do
        show_html :state
        show_button :close, :abort
      end
    end
  end

  def rpc_list_choice( session, name, args )
    dputs( 3 ){ "rpc_list_choice with #{name} - #{args.inspect}" }
    ret = reply('empty', ['diplomas'])
    case name
    when "courses"
      if args['courses'].length > 0
        course = Entities.Courses.match_by_course_id( args['courses'].to_a[0] )
        course and ret += reply( :update, :diplomas => course.get_files )
      end
    end
    return ret
  end

  def rpc_button_do_diplomas( session, args )
    course_id = args['courses'][0]
    course = Courses.match_by_course_id(course_id)
    if not course or course.export_check
      if course
        return reply( :window_show, :missing_data ) +
          reply( :update, :missing => "The following fields are not filled in:<br>" + 
            course.export_check.join("<br>"))
      end
    else
      course.prepare_diplomas

      rpc_list_choice( session, :courses, :courses => course_id.to_s ) +
        reply( :auto_update, "-5" ) +
        reply( :window_show, :create_diplomas ) +
        reply( :hide, :close ) +
        reply( :unhide, :abort ) +
        reply( :update, :state => "Preparing -<br>Please wait")
    end
  end
  
  def rpc_update_with_values( session, args )
    course_id = args['courses'][0]
    ret = rpc_list_choice( session, "courses", "courses" => course_id.to_s )
    course = Entities.Courses.match_by_course_id( course_id )
    #if course.get_files.index{|f| f =~ /(000-4pp.pdf|zip)$/ }
    overall_state = course.make_pdfs_state["0"]
    if overall_state == "done"
      ret += reply( :auto_update, 0 ) +
        reply( :hide, :abort ) +
        reply( :unhide, :close )
    end
    state = "<table border='1'><tr><th>Name</th><th>Grade</th><th>State</th></tr>" + 
      course.make_pdfs_state.keys.reject{|k| k == "0"}.sort.collect{|s|
      state = course.make_pdfs_state[s]
      "<tr><td>#{s}</td><td align='right'>#{state[0]}</td><td>#{state[1]}</td></tr>"
    }.join("") + "</table><br>" +
      "Progress: #{overall_state}"
    dputs(0){course.make_pdfs_state.inspect}
    dputs(0){state.inspect}
    return ret + 
      reply_print( session ) +
      reply( :update, :state => state )
  end

  def rpc_button_close( session, args )
    reply( "window_hide" )
  end
  
  def rpc_button_print( session, args )
    ret = rpc_print( session, :print, args )
    lp_cmd = cmd_printer( session, :print )
    if args['diplomas'].length > 0
      course_id = args['courses'][0]
      course = Courses.match_by_course_id(course_id)
      dputs( 2 ){ "Printing #{args['diplomas'].inspect}" }
      if lp_cmd
        args['diplomas'].each{|g|
          `#{lp_cmd} #{course.dir_diplomas}/#{g}`
        }
        ret += reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression de<ul><li>#{args['diplomas'].join('</li><li>')}</li></ul>en cours" )
      else
        ret += reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Choisir le pdf:<ul>" +
            args['diplomas'].collect{|d|
            %x[ cp #{course.dir_diplomas}/#{d} /tmp ] 
            "<li><a href=\"/tmp/#{d}\">#{d}</a></li>"
          }.join('') + "</ul>" )
      end
    end
    ret
  end
  
  def rpc_button_abort( session, args )
    course_id = args['courses'][0]
    course = Entities.Courses.match_by_course_id( course_id )
    course.abort_pdfs
    reply( :window_hide ) +
      reply( :auto_update, 0 )
  end
end
