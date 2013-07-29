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
    @update = true

    gui_hbox do
      gui_vbox :nogroup do
        #show_list :diplomas
        show_html :diplomas
        show_table :diplomas_t, :headings => [:name, :state, :grade]
      end
      gui_vbox :nogroup do
        show_button :do_diplomas, :abort
        show_button :prepare_print
      end
      gui_window :missing_data do
        show_html :missing
        show_button :close
      end
      gui_window :printing do
        show_html :msg_print
        show_button :close
      end
      gui_window :prepare_print do
        show_list :diplomas_files
        show_print :print
      end
    end
  end
  
  def rpc_show( session )
    super( session ) +
      reply( :hide, :abort ) +
      reply( :update, :diplomas_t => [[1,2,3],[4,5,6]])
  end
  
  def rpc_update( session )
    super( session ) +
      reply_print( session )
  end

  def rpc_list_choice( session, name, args )
    args.to_sym!
    ddputs( 3 ){ "rpc_list_choice with #{name.inspect} - #{args.inspect}" }
    ret = []
    case name.to_s
    when "courses"
      ret = reply( :empty, [:diplomas])
      if args._courses.length > 0
        if course = Entities.Courses.match_by_course_id( args._courses.to_a[0] )
          course.update_state
          ret += rpc_update_with_values( session, args )
        end
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

      rpc_list_choice( session, :courses, :courses => [course_id.to_s] ) +
        reply( :update, :diplomas => "Preparing -<br>Please wait")
    end
  end
  
  def rpc_update_with_values( session, args )
    args.to_sym!
    ( course_id = args._courses[0] ) or return []
    #ret = rpc_list_choice( session, "courses", "courses" => course_id.to_s )
    ret = []
    ( course = Entities.Courses.match_by_course_id( course_id ) ) or return []
    #if course.get_files.index{|f| f =~ /(000-4pp.pdf|zip)$/ }
    overall_state = course.make_pdfs_state["0"]
    if overall_state == "done"
      ret += reply( :auto_update, 0 ) +
        reply( :hide, :abort ) +
        reply( :unhide, :do_diplomas )
    else
      ret += reply( :auto_update, -1 ) +
        reply( :unhide, :abort ) +
        reply( :hide, :do_diplomas )
    end
    header = "<table border='1'><tr><th>Name</th><th>Grade</th><th>State</th></tr>"
    footer = "</table>"
    keys = course.make_pdfs_state.keys.reject{|k| k == "0"}
    index = 0
    state = "<table><tr><td>#{header}" + 
      keys.sort.collect{|s|
      state = course.make_pdfs_state[s]
      str = "<tr><td>#{s}</td><td align='right'>#{state[0]}</td><td>#{state[1]}</td></tr>"
      index += 1
      if ( keys.length > 10 ) and ( index == ( ( keys.length + 1 ) / 2 ) )
        str += "#{footer}</td><td>#{header}"
      end
      str
    }.join("") + footer + "</td></tr></table>" +
      "<br>Progress: #{overall_state}"
    dputs(3){course.make_pdfs_state.inspect}
    dputs(3){state.inspect}
    return ret + 
      reply_print( session ) +
      reply( :update, :diplomas => state )
  end

  def rpc_button_close( session, args )
    reply( :window_hide )
  end
  
  def rpc_button_print( session, args )
    ret = rpc_print( session, :print, args ) +
      reply( :window_hide )
    lp_cmd = cmd_printer( session, :print )
    if ( files = args['diplomas_files'] ).length > 0
      course_id = args['courses'][0]
      course = Courses.match_by_course_id(course_id)
      dputs( 2 ){ "Printing #{files.inspect}" }
      if lp_cmd
        files.each{|g|
          `#{lp_cmd} #{course.dir_diplomas}/#{g}`
        }
        ret += reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression de<ul><li>#{files.join('</li><li>')}</li></ul>en cours" )
      else
        ret += reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Choisir le pdf:<ul>" +
            files.collect{|d|
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
    reply( :unhide, :do_diplomas ) +
      reply( :hide, :abort ) +
      reply( :auto_update, 0 )
  end
  
  def rpc_button_prepare_print( session, args )
    course = Entities.Courses.match_by_course_id( args['courses'][0] )
    reply( :window_show, :prepare_print ) +
      reply( :update, :diplomas_files => course.get_files )
  end
end
