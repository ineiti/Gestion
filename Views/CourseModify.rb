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
    
    gui_hbox do
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_list_single :courses, "Entities.Courses.list_courses", :callback => true
          show_button :add_course, :delete, :export
        end
        gui_window :course do
          show_list_drop :name_base, "Entities.Courses.list_name_base"
          show_str :name_date
          show_button :new_course, :close
        end
        gui_window :export do
          show_text :attestations
          show_button :close
        end
      end
      gui_vbox :nogroup do
        show_block :name
        show_block :calendar
        show_block :teacher
        show_block :accounting
        show_button :save
      end
      gui_vbox :nogroup do
        show_block :content
        show_list :students
        show_button :add_students, :bulk_add, :del_student
      end
      gui_window :students_win do
        show_list :students_add, "Entities.Persons.list_students"
        show_str :search, :gui => %w( update )
        show_button :new_student, :close
      end
      gui_window :students_bulk do
        show_text :names
        show_button :bulk_students, :close
      end
      gui_window :missing_data do
        show_str :missing
        show_button :close
      end
    end
  end
  
  def rpc_button_delete( sid, data )
    dputs 3, "sid, data: #{[sid, data.inspect].join(':')}"
    course = @data_class.find_by_course_id( data['courses'][0])
    dputs 3, "Got #{course.name} - #{course.inspect}"
    if course
      dputs 2, "Deleting entry #{course}"
      course.delete
    end
    
    reply( "empty", [:courses] ) +
    reply( "update", { :courses => @data_class.list_courses } )
  end
  
  def rpc_button_save( sid, data )
    course = @data_class.find_by_name( data['name'] )
    if course 
      # BUG: they're already saved, don't save it again
      data.delete( 'students' )
      course.set_data( data )
    end
  end
  
  def rpc_button_export( sid, data )
  end
  
  def rpc_button_add_students( sid, data )
    reply( "window_show", "students_win" )
  end
  
  def rpc_button_bulk_add( sid, data )
    if data['name']
      reply( "window_show", "students_bulk" )
    end
  end
  
  def rpc_button_del_student( sid, data )
    course = @data_class.find_by_name( data['name'] )
    data['students'].each{|s|
      course.students.delete( s)  
    }
    reply( "empty_only", [:students] ) + reply( "update", course.data )
  end
  
  def rpc_button_new_student( sid, data )
    course = @data_class.find_by_name( data['name'] )
    if course
      if not course.students.class == Array
        course.students = []
      end
      data['students_add'].each{|s|
        if not course.students.index( s )
          course.students.push( s )
        end
      }
      dputs 3, "Students are now: #{course.students.inspect}"
      reply( "empty_only", [:students] ) + 
      reply( "update", { :students => course.list_students } ) +
      reply( "window_hide" )
    end
  end
  
  # This will add a whole lot of students to the list, creating them and setting
  # the permissions to "student", but without generating a password
  # As the creation of a student can take quite some time (10s of seconds),
  # only one student is created, then the list updated, and a new request is
  # automatically generated.
  def rpc_button_bulk_students( sid, data )
    dputs 3, data.inspect
    course = @data_class.find_by_name( data['name'] )
    users = []
    if data['names'] and users = data['names'].split("\n")
      u = users.shift
      names = u.split(' ')
      # Trying to be intelligent about splitting up of names
      s = names.length < 4 ? 0 : 1
      first = names[0..s].join(" ")
      family = names[(s+1)..-1].join(" ")
      dputs 1, "Creating user #{u.inspect} as #{first} - #{family}"
      person = Entities.Persons.create( {:first_name => first, :family_name => family, 
        :permissions => %w( student ), :town => @town, :country => @country })
      person.email = "#{person.login_name}@ndjair.net"
      course.students.push( person.login_name )
      if defined? @cmd_after_new
          %x[ #{@cmd_after_new} #{person.login_name} ]
      end
    end
    if users.length > 0
      reply( "update", { :names => users.join("\n") } ) +
      reply( "callback_button", "bulk_students" )
    else
      reply( "empty_only", [:students] ) + 
      reply( "update", { :students => course.list_students } ) +
      reply( "window_hide" )      
    end
  end
  
  def rpc_button_add_course( sid, data)
    reply( "window_show", "course" )
  end
  
  def rpc_button_new_course( sid, data )
    dputs 3, "sid: #{sid} - data: #{data.inspect}"
    
    name = "#{data['name_base'][0]}_#{data['name_date']}"
    course = @data_class.find_by_name( name )
    if name =~ /_.+/
      if not course
        course = @data_class.create( {:name => name })
      end
    end
    
    reply("empty", [:students, :courses]) +
    reply( "update", {:courses => Entities.Courses.list_courses}) +
    reply( "update", course.to_hash ) +
    reply( "update", { :courses => [ course.course_id ] }) +
    reply( "window_hide" )
  end
  
  def rpc_button_close( sid, data )
    reply( "window_hide", "*" )
  end
  
  def rpc_list_choice( sid, name, *args )
    #Calling rpc_list_choice with [["courses", {"courses"=>["base_25"], "name_base"=>["base"]}]]
    dputs 3, "rpc_list_choice with #{name} - #{args.inspect}"
    if name == "courses"
      course_id = args[0]['courses'][0]
      dputs 3, "replying"
      course = @data_class.find_by_course_id(course_id)
      reply("empty", [:students]) +
      reply("update", course.to_hash ) +
      reply("update", {:courses => [course_id] } )
    end
  end
  
end
