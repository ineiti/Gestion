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
              show_list :students, :flexheight => 1
              show_button :bulk_add, :del_student, :edit_student
            end
            show_print :print_student
          end
        end
        gui_window :students_bulk do
          show_text :names
          show_button :bulk_students, :close
        end
        gui_window :ask_double do
          show_str :double_name
          show_entity_person_lazy :double_proposition, :drop, :full_name
          show_button :accept, :create_new
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
            rep.collect{|r| "<li><a target='other' href=\"#{r}\">#{r}</a></li>" }.join('') +
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
          reply( "update", :missing => "Click on the link: <a target='other' href=\"#{rep}\">PDF</a>" )
      end
    end
  end

  # This will add a whole lot of students to the list, creating them and setting
  # the permissions to "student" and setting a simple, 4-digit password
  # As the creation of a student can take quite some time (10s of seconds),
  # only one student is created, then the list updated, and a new request is
  # automatically generated.
  def rpc_button_bulk_students( session, data )
    dputs( 3 ){ data.inspect }
    course = Courses.match_by_name( data['name'] )
    users = []
    session.s_data[:perhaps_double] ||= []
    if data['names'] and users = data['names'].split("\n")
      prefix = ConfigBase.has_function?( :course_server ) ?
        "#{session.owner.login_name}_" : ""
      name = users.shift
      login_name = Persons.create_login_name( name )
      if not ( person = Persons.match_by_login_name( prefix + name ) )
        if Persons.search_by_login_name( "^#{prefix}#{login_name}[0-9]*$").length > 0
          session.s_data[:perhaps_double].push name
        else
          person = Persons.create( {:first_name => name,
              :login_name_prefix => prefix,
              :permissions => %w( student ), :town => @town, :country => @country })
        end
      end
      #person.email = "#{person.login_name}@ndjair.net"
      person and course.students.push( person.login_name )
    end
    if users.length > 0
      reply( "update", { :names => users.join("\n") } ) +
        update_students( course ) +
        reply( :callback_button, :bulk_students )
    else
      update_students( course ) +
        reply( :update, {:names => ""} ) +
        reply( :window_hide ) +
        present_doubles( session, course )
    end
  end
  
  def present_doubles( session, course )
    doubles = session.s_data[:perhaps_double]
    dputs(4){"Doubles are #{doubles.inspect}"}
    if doubles.length > 0
      prefix = ConfigBase.has_function?( :course_server ) ?
        "#{session.owner.login_name}_" : ""
      name = doubles.pop
      login_name = Persons.create_login_name( name )
      prop = Persons.search_by_login_name( "^#{prefix}#{login_name}[0-9]*$").
        collect{|p|
        courses = Courses.matches_by_students( p.login_name ).collect{|c| c.name }.
          join("-")
        [p.person_id, "#{p.full_name}:#{p.login_name}:#{courses}"]
      }
      dputs(4){"Proposition is #{prop.inspect}"}
      reply( :window_show, :ask_double ) +
        reply( :update, :double_name => name ) +
        reply( :empty_only, [:double_proposition ]) +
        reply( :update, :double_proposition => prop )
    else
      reply( :window_hide )
    end +
      update_students( course )
  end
  
  def rpc_button_accept( session, data )
    course = Courses.match_by_name( data['name'] )
    student = data['double_proposition']
    dputs(5){"Data is #{data.inspect} - #{course.students.inspect}"}
    if not course.students.index( student.login_name )
      course.students.push(
        student.login_name )
    end
    present_doubles( session, course )
  end
  
  def rpc_button_create_new( session, data )
    course = Courses.match_by_name( data['name'] )
    prefix = ConfigBase.has_function?( :course_server ) ?
      "#{session.owner.login_name}_" : ""
    name = data['double_name']
    course.students.push Persons.create( {:first_name => name,
        :login_name_prefix => prefix,
        :permissions => %w( student ), :town => @town, :country => @country }).
      login_name
    present_doubles( session, course )
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
        update_form_data( course ) +
        reply("update", {:courses => [course_id] } )
      #else
      #  reply("empty", [:students])
    end
  end
  
  def hide_if_center( session )
    if session.owner.permissions.index( "center" )
      %w( print_student duration dow hours
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
      hide_if_center( session )
  end
  
  def update_layout( session )
    resps = Persons.search_by_permissions( "teacher" )
    if session.owner.permissions.index( "center" )
      resps = resps.select{|p|
        p.login_name =~ /^#{session.owner.login_name}_/
      }
    end
    resps = resps.collect{|p|
      [p.person_id, p.full_name]
    }
    
    fields = %w( teacher assistant responsible )
    
    super( session ) +
      reply( :empty, fields ) +
      reply( :update, :assistant => [[0, "---"]]) +
      fields.collect{|p|
      reply( :update, p => resps )
    }.flatten
  end
  
  def rpc_update_hook( session, one, two )
    update_layout( session )
  end
end
