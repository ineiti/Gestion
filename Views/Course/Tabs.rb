class CourseTabs < View
  def layout
    @order = 20
    @update = true

    gui_window :error do
      show_html "<h1>You're not allowed to do that</h1>"
      show_button :close
    end
    
    gui_window :not_all_elements do
      show_html :msg, "<h1>Some elements are missing</h1>"
      show_button :add_elements
    end
    
    gui_vboxg :nogroup do
      show_list_single :courses, :callback => true
      show_button :delete
    end
  end
  
  def rpc_update( session )
    if CourseTypes.search_all.size == 0
      reply( :window_show, :not_all_elements ) +
        reply( :update, :msg => "Please define a coursetype first" )
    elsif Rooms.search_all.size == 0
      reply( :window_show, :not_all_elements ) +
        reply( :update, :msg => "Please define a room first" )
    elsif Persons.search_by_permissions( "teacher" ).size == 0
      reply( :window_show, :not_all_elements ) +
        reply( :update, :msg => "Please define a teacher first" )
    else
      rep = reply( :empty, [ :courses ] ) +
        reply( :update, :courses => Entities.Courses.list_courses(session))
      if not session.can_view( 'CourseAdd' )
        rep += reply( :hide, :delete )
      end
      rep
    end    
  end
  
  def rpc_button_add_elements( session, args )
    if CourseTypes.search_all.size == 0
      reply( :window_hide ) +
        reply( :switch_tab, :AdminTabs ) +
        reply( :child, reply( :switch_tab, :AdminCourseType ) )
    elsif Rooms.search_all.size == 0
      reply( :window_hide ) +
        reply( :switch_tab, :InventoryTabs ) +
        reply( :child, reply( :switch_tab, :InventoryRoom ) )
    elsif Persons.search_by_permissions( "teacher" ).size == 0
      reply( :window_hide ) +
        reply( :switch_tab, :PersonTabs ) +
        reply( :child, reply( :switch_tab, :PersonModify ) )
    end
  end

  def rpc_button_delete( session, args )
    if not session.can_view( 'CourseAdd' )
      reply( :window_show, :error )
    end
    dputs( 3 ){ "session, data: #{[session, data.inspect].join(':')}" }
    course = Courses.find_by_course_id( args['courses'][0])
    dputs( 3 ){ "Got #{course.name} - #{course.inspect}" }
    if course
      dputs( 2 ){ "Deleting entry #{course}" }
      course.delete
    end

    reply( "empty", [:courses] ) +
      reply( "update", { :courses => Courses.list_courses } ) +
      reply( :child, reply(:empty, [:students]) )
  end

  def rpc_list_choice( session, name, args )
    dputs( 2 ){ "New choice #{name} - #{args.inspect}" }

    reply( 'pass_tabs', [ "list_choice", name, args ] )
  end
end
