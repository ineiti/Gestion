class CourseTabs < View
  def layout
    @order = 20
    @update = true
    @functions_need = [:courses]

    gui_window :error do
      show_html "<h1>You're not allowed to do that</h1>"
      show_button :close
    end
    
    gui_window :not_all_elements do
      gui_vbox do
        gui_vbox :nogroup do
          show_str :ct_name
          show_int :ct_duration
          show_str :ct_desc
          show_text :ct_contents
        end
        gui_vbox :nogroup do
          show_str :new_room
        end
        gui_vbox :nogroup do
          show_str :new_teacher
        end
        show_button :add_missing
      end
    end
    
    gui_vboxg :nogroup do
      show_list_single :courses, :callback => true
      show_button :delete
    end
  end
  
  def rpc_update( session )
    hide = []
    if CourseTypes.search_all.size > 0
      hide.push :ct_name, :ct_duration, :ct_desc, :ct_contents
    end
    if Rooms.search_all.size > 0
      hide.push :new_room
    end
    if Persons.search_by_permissions( "teacher" ).size > 0
      hide.push :new_teacher
    end
    if hide.size < 6
      ( reply( :window_show, :not_all_elements ) +
          hide.collect{|h| reply( :hide, h ) } ).flatten
      #      reply( :window_show, :not_all_elements ) +
      #        reply( :hide, hide )
    else
      rep = reply( :empty, [ :courses ] ) +
        reply( :update, :courses => Entities.Courses.list_courses(session))
      if not session.can_view( 'CourseAdd' )
        rep += reply( :hide, :delete )
      end
      rep
    end    
  end
  
  #      reply( :window_hide ) +
  #        reply( :switch_tab, :AdminTabs ) +
  #        reply( :child, reply( :switch_tab, :AdminCourseType ) )
  def rpc_button_add_missing( session, args )
    args.to_sym!
    ddputs(5){args.inspect}
    if args._ct_name and args._ct_name.size > 0
      ddputs(3){"Creating CourseType"}
      ct = CourseTypes.create( :name => args._ct_name, :duration => args._ct_duration,
        :tests => 1, :description => args._ct_desc, :contents => args._ct_contents,
        :diploma_type => ["simple"], :output => ["certificate"])
      ddputs(3){"Ct is #{ct.inspect}"}
    end
    if args._new_room and args._new_room.size > 0
      ddputs(3){"Creating Room"}
      room = Rooms.create( :name => args._new_room )
      ddputs(3){"Room is #{room.inspect}"}
    end
    if args._new_teacher and args._new_teacher.size > 0
      ddputs(3){"Creating Teacher"}
      teacher = Persons.create( :complete_name => args._new_teacher )
      teacher.permissions = [:teacher]
      ddputs(3){"Teacher #{teacher.inspect}"}
    end
    reply( :window_hide ) +
      rpc_update( session ) +
      reply( :pass_tabs, [ :update_hook ] )
  end

  def rpc_button_delete( session, args )
    if not session.can_view( 'CourseAdd' )
      reply( :window_show, :error )
    end
    dputs( 3 ){ "session, data: #{[session, args.inspect].join(':')}" }
    course = Courses.match_by_course_id( args['courses'][0])
    dputs( 3 ){ "Got #{course.name} - #{course.inspect}" }
    if course
      dputs( 2 ){ "Deleting entry #{course}" }
      course.delete
    end

    reply( "empty", [:courses] ) +
      reply( "update", { :courses => Courses.list_courses(session) } ) +
      reply( :child, reply(:empty, [:students]) )
  end

  def rpc_list_choice( session, name, args )
    dputs( 2 ){ "New choice #{name} - #{args.inspect}" }

    reply( 'pass_tabs', [ "list_choice", name, args ] )
  end
end
