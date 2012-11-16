# Let's you add, modify and delete a course, as well as manage students.
# It is written to work together with a Moodle-installation. Moodle-configuration
# over LDAP is:
# - First name: sn
# - Name: givenName
# - E-mail: mail
# - Town: l
# - Country: st
# - Telephone1: mobile
#
# Configuration
# town - the default town
# country - the default country

class CourseModify < View
  def layout
    set_data_class :Courses
    @update = true
    @order = 10

    gui_hbox do
      gui_vbox :nogroup do
        show_block :name
        show_arg :name, :ro => true
        show_block :calendar
        show_block :teacher
        show_button :save
      end
      gui_vbox :nogroup do
        show_block :content
        show_button :print_presence
        gui_vbox :nogroup do
          show_list :students
          show_button :bulk_add, :del_student, :edit_student, :print_student
        end
      end
      gui_window :students_bulk do
        show_text :names
        show_button :bulk_students, :close
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

  def rpc_button_delete( session, data )
    dputs( 3 ){ "session, data: #{[session, data.inspect].join(':')}" }
    course = Courses.find_by_course_id( data['courses'][0])
    dputs( 3 ){ "Got #{course.name} - #{course.inspect}" }
    if course
      dputs( 2 ){ "Deleting entry #{course}" }
      course.delete
    end

    reply( "empty", [:courses] ) +
      reply( "update", { :courses => Courses.list_courses } )
  end

  def rpc_button_save( session, data )
    course = Courses.find_by_name( data['name'] )
    if course
      # BUG: they're already saved, don't save it again
      data.delete( 'students' )
      course.data_set_hash( data )
    end
  end

=begin
  def rpc_button_add_students( session, data )
    reply( "window_show", "students_win" )
  end
=end

  def rpc_button_bulk_add( session, data )
    if data['name']
      reply( "window_show", "students_bulk" )
    end
  end

  def update_students( course )
    reply( "empty_only", [:students] ) +
      reply( "update", { :students => course.list_students } )
  end

  def rpc_button_del_student( session, data )
    course = Courses.find_by_name( data['name'] )
    data['students'].each{|s|
      course.students.delete( s )
    }
    update_students( course )
  end

  def rpc_button_edit_student( session, data )
    dputs( 0 ){ "data is: #{data.inspect}" }
    login = data["students"][0]
    reply( "parent",
      reply( :init_values, [ :PersonTabs, { :search => login, :persons => [] } ] ) +
        reply( :switch_tab, :PersonTabs ) ) + 
      reply( :switch_tab, :PersonModify )
  end

  def rpc_button_print_student( session, data )
    rep = []
    data['students'].each{|s|
      student = Persons.find_by_login_name( s )
      dputs( 1 ){ "Printing student #{student.full_name}" }
      rep.push student.print( rep.length )
    }
    if data['students']
      if rep[0].class == String
        reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Click on one of the links:<ul>" +
            rep.collect{|r| "<li><a href=\"#{r}\">#{r}</a></li>" }.join('') +
            "</ul>" )
      else
        reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression de<ul><li>#{data['students'].join('</li><li>')}</li></ul>en cours" )
      end
    end
  end

  def rpc_button_print_presence( session, data )
    case rep = Courses.find_by_name( data['name'] ).print_presence
    when true
      reply( :window_show, :printing ) +
        reply( :update, :msg_print => "Impression de la fiche de présence pour<br>#{data['name']} en cours" )
    when false
      reply( "window_show", "missing_data" ) +
        reply( "update", :missing => "One of the following is missing:<ul><li>date</li><li>students</li><li>teacher</li></ul>" )
    else
      reply( "window_show", "missing_data" ) +
        reply( "update", :missing => "Click on the link: <a href=\"#{rep}\">PDF</a>" )
    end
  end

  # This will add a whole lot of students to the list, creating them and setting
  # the permissions to "student", but without generating a password
  # As the creation of a student can take quite some time (10s of seconds),
  # only one student is created, then the list updated, and a new request is
  # automatically generated.
  def rpc_button_bulk_students( session, data )
    dputs( 3 ){ data.inspect }
    course = Courses.find_by_name( data['name'] )
    users = []
    if data['names'] and users = data['names'].split("\n")
      person = Entities.Persons.create( {:first_name => users.shift,
          :permissions => %w( student ), :town => @town, :country => @country })
      person.email = "#{person.login_name}@ndjair.net"
      course.students.push( person.login_name )
    end
    if users.length > 0
      reply( "update", { :names => users.join("\n") } ) +
        reply( "callback_button", "bulk_students" )
    else
      update_students( course ) +
        reply( "window_hide" )
    end
  end

  def rpc_button_close( session, data )
    reply( "window_hide", "*" )
  end

  def rpc_list_choice( session, name, args )
    #Calling rpc_list_choice with [["courses", {"courses"=>["base_25"], "name_base"=>["base"]}]]
    dputs( 3 ){ "rpc_list_choice with #{name} - #{args.inspect}" }
    if name == "courses" and args['courses'].length > 0
      course_id = args['courses'][0]
      dputs( 3 ){ "replying for course_id #{course_id}" }
      course = Courses.find_by_course_id(course_id)
      reply("empty", [:students]) +
        reply("update", course.to_hash ) +
        reply("update", {:courses => [course_id] } )
    else
      reply("empty", [:students])
    end
  end

  def rpc_update( session )
    reply( 'empty', [:students] ) +
      super( session )
  end

end
