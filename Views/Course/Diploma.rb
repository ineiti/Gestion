=begin
Shows the existing courses and the courses on the server, so that the
two can be synchronized.
=end


class CourseDiploma < View
  def layout
    set_data_class :Courses
    @order = 30
    @thread = nil

    gui_hbox do
      gui_vbox :nogroup do
        show_list :diplomas
        show_button :do_diplomas, :print
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
    
    @default_printer = $config[:default_printer] ? "-P #{$config[:default_printer]}" : nil
  end

  def rpc_list_choice( session, name, args )
    dputs( 3 ){ "rpc_list_choice with #{name} - #{args.inspect}" }
    ret = reply('empty', ['diplomas'])
    case name
    when "courses"
      if args['courses'].length > 0
        course = Entities.Courses.find_by_course_id( args['courses'].to_a[0] )
        course and ret += reply( 'update', :diplomas => course.get_pdfs )
      end
    end
    return ret
  end

  def rpc_button_do_diplomas( session, args )
    course_id = args['courses'][0]
    course = Courses.find_by_course_id(course_id)
    if not course or course.export_check
      if course
        return reply( "window_show", :missing_data ) +
					reply("update", :missing => "The following fields are not filled in:<br>" + 
						course.export_check.join("<br>"))
      end
    else
			course.prepare_diplomas

      rpc_list_choice( session, "courses", "courses" => course_id.to_s ) +
				reply( "auto_update", "-5" )
    end
  end
  
  def rpc_update_with_values( session, args )
    course_id = args['courses'][0]
    ret = rpc_list_choice( session, "courses", "courses" => course_id.to_s )
    course = Entities.Courses.find_by_course_id( course_id )
    if course.get_pdfs.index( "000-4pp.pdf" )
      ret += reply( :auto_update, 0 )
    end
    return ret
  end

  def rpc_button_close( session, args )
    reply( "window_hide" )
  end
  
  def rpc_button_print( session, args )
    ret = nil
    if args['diplomas'].length > 0
      course_id = args['courses'][0]
      course = Courses.find_by_course_id(course_id)
      dputs( 2 ){ "Printing #{args['diplomas'].inspect}" }
      if @default_printer
        args['diplomas'].each{|g|
          `lpr #{@default_printer} #{course.diploma_dir}/#{g}`
        }
        ret = reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression de<ul><li>#{args['diplomas'].join('</li><li>')}</li></ul>en cours" )
      else
        ret = reply( :window_show, :printing ) +
					reply( :update, :msg_print => "Choisir le pdf:<ul>" +
						args['diplomas'].collect{|d|
						%x[ cp #{course.diploma_dir}/#{d} /tmp ] 
						"<li><a href=\"/tmp/#{d}\">#{d}</a></li>"
					}.join('') + "</ul>" )
      end
    end
    ret
  end
end
