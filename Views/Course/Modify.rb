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
  include PrintButton
  
  def layout
    set_data_class :Courses
    @update = true
    @order = 10

    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_block :name
          show_arg :name, :ro => true
          show_block :calendar
          show_block :teacher
        end
        gui_vbox :nogroup do
          show_block :content
        
          show_print :print_presence
          gui_vbox do
            gui_fields do
              show_list :students
              show_button :bulk_add, :del_student, :edit_student
            end
            show_print :print_student
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
      show_button :save
    end
  end

  def rpc_button_save( session, data )
    if course = Courses.match_by_name( data['name'] )
      # BUG: they're already saved, don't save it again
      dputs(4){"Found course #{course.inspect}"}
      data.delete( 'students' )
      dputs(4){"Setting data #{data}"}
      course.data_set_hash( data )
    else
      dputs(5){"Didn't find course #{data['name']}"}
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
    course = Courses.match_by_name( data['name'] )
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
    ret = rpc_print( session, :print_student, data )
    lp_cmd = cmd_printer( session, :print_student )
    data['students'].each{|s|
      student = Persons.match_by_login_name( s )
      dputs( 1 ){ "Printing student #{student.full_name}" }
      student.lp_cmd = lp_cmd
      rep.push student.print( rep.length )
    }
    if data['students']
      if rep[0].class == String
        ret = reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Click on one of the links:<ul>" +
            rep.collect{|r| "<li><a href=\"#{r}\">#{r}</a></li>" }.join('') +
            "</ul>" )
      elsif rep.length > 0
        ret = reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression de<ul><li>#{data['students'].join('</li><li>')}</li></ul>en cours" )
      end
    end
    ret
  end

  def rpc_button_print_presence( session, data )
    ret = rpc_print( session, :print_presence, data )
    lp_cmd = cmd_printer( session, :print_presence )
    if data['name'] and data['name'].length > 0
      case rep = Courses.match_by_name( data['name'] ).print_presence( lp_cmd )
      when true
        ret + reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression de la fiche de présence pour<br>#{data['name']} en cours" )
      when false
        ret + reply( "window_show", "missing_data" ) +
          reply( "update", :missing => "One of the following is missing:<ul><li>date</li><li>students</li><li>teacher</li></ul>" )
      else
        ret + reply( "window_show", "missing_data" ) +
          reply( "update", :missing => "Click on the link: <a href=\"#{rep}\">PDF</a>" )
      end
    end
  end

  # This will add a whole lot of students to the list, creating them and setting
  # the permissions to "student", but without generating a password
  # As the creation of a student can take quite some time (10s of seconds),
  # only one student is created, then the list updated, and a new request is
  # automatically generated.
  def rpc_button_bulk_students( session, data )
    dputs( 3 ){ data.inspect }
    course = Courses.match_by_name( data['name'] )
    users = []
    if data['names'] and users = data['names'].split("\n")
      prefix = session.owner.permissions.index("center") ?
        "#{session.owner.login_name}_" : ""
      name = users.shift
      if not ( person = Persons.match_by_login_name( prefix + name ) )
        person = Entities.Persons.create( {:first_name => name,
            :login_name_prefix => prefix,
            :permissions => %w( student ), :town => @town, :country => @country })
      end
      #person.email = "#{person.login_name}@ndjair.net"
      course.students.push( person.login_name )
    end
    if users.length > 0
      reply( "update", { :names => users.join("\n") } ) +
        update_students( course ) +
        reply( "callback_button", "bulk_students" )
    else
      update_students( course ) +
        reply( :update, {:names => ""} ) +
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
      course = Courses.match_by_course_id(course_id)
      reply("empty", [:students]) +
        reply("update", course.to_hash ) +
        reply("update", {:courses => [course_id] } )
    else
      reply("empty", [:students])
    end
  end
  
  def center?( session )
    if session.owner.permissions.index( "center" )
      %w( print_presence print_student edit_student duration dow hours
      classroom ).collect{|e|
        reply( :hide, e )        
      }.flatten
    else
      []
    end
  end

  def rpc_update( session )
    reply( 'empty', [:students] ) +
      super( session ) +
      reply_print( session ) +
      center?( session )
  end

end
