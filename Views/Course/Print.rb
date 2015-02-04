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
        show_print :print_exam_file
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

  def rpc_update(session)
    super(session) +
        reply_print(session)
  end

  def rpc_list_choice_courses(session, args)
    dputs(3) { "rpc_list_choice with #{name} - #{args.inspect}" }
    if args._courses.length > 0
      course_id = args._courses[0]
      dputs(3) { "replying for course_id #{course_id}" }
      course = Courses.match_by_course_id(course_id)
      reply_visible(course.ctype.file_exam.to_s.length > 0, :print_exam_file)
    end
  end

  def rpc_button_print_presence(session, data)
    dputs(3) { 'printing' }
    ret = rpc_print(session, :print_presence, data)
    lp_cmd = cmd_printer(session, :print_presence)
    course = Courses.match_by_course_id(data._courses[0])
    if data._courses and data._courses.length > 0
      case rep = course.print_presence(lp_cmd)
        when true
          ret + reply(:window_show, :printing) +
              reply(:update, :msg_print => 'Impression - de la fiche de présence pour<br>' +
                  "#{course.name} en cours")
        when false
          ret + reply(:window_show, :missing_data) +
              reply(:update, :missing => 'One of the following is missing:<ul><li>date</li>' +
                  '<li>students</li><li>teacher</li></ul>')
        else
          ret + reply(:window_show, :missing_data) +
              reply(:update, :missing => "Click on the link: <a target='other' href=\"#{rep}\">" +
                  'PDF</a>')
      end
    end
  end

  def rpc_button_print_exam_file(session, data)
    dputs(3) { "printing with #{data._courses.inspect}" }
    exa = 'print_exam_file'
    ret = rpc_print(session, exa, data)
    lp_cmd = cmd_printer(session, exa)
    course = Courses.match_by_course_id(data._courses[0])
    dputs(3){"lp_cmd is #{lp_cmd}"}
    if data._courses && data._courses.length > 0
      case rep = course.print_exam_file(lp_cmd)
        when true
          ret += reply(:window_show, :printing) +
              reply(:update, :msg_print => "Impression de la fiche d'évaluation pour<br>"+
                               "#{course.name} en cours")
        when false
          ret += reply(:window_show, :missing_data) +
              reply(:update, :missing => 'One of the following is missing:<ul><li>date</li>'+
                               '<li>students</li><li>teacher</li></ul>')
        else
          ret += reply(:window_show, :missing_data) +
              reply(:update, :missing => "Click on the link: <a target='other' href=\"#{rep}\">"+
                               'PDF</a>')
      end
    end
    return ret
  end

  def rpc_button_close(session, data)
    reply(:window_hide)
  end
end
