class CourseAdd < View
  def layout
    set_data_class :Courses
    @update = true
    @order = 50

    gui_hbox do
      gui_vbox :nogroup do
        show_entity_courseType :ctype, :drop, :name
        show_str :name_date
        show_button :new_course
      end
    end
  end

  def rpc_button_save( session, data )
    course = Courses.find_by_name( data['name'] )
    if course
      # BUG: they're already saved, don't save it again
      data.delete( 'students' )
      course.data_set_hash( data )
    end
  end

  def rpc_button_new_course( session, data )
    dputs( 3 ){ "session: #{session} - data: #{data.inspect}" }

    ctype = data['ctype']
    if center = session.owner.permissions.index( "center" )
      data['name_date'] = "#{session.owner.login_name}-#{data['name_date']}"
    end
    name = "#{ctype.name}_#{data['name_date']}"
    if not ( course = Courses.find_by_name( name ) )
      course = Courses.create_ctype( data['name_date'], ctype )
      if center
        course.responsible = session.owner
      end
      dputs(0){"Course in if is #{course.inspect}"}
    end
    dputs(0){"Course is #{course.inspect}"}

    reply( "parent",
      View.CourseTabs.rpc_update( session ) +
        reply( "update", { :courses => [ course.course_id ] } ) ) +
      reply( "switch_tab", :CourseModify )
  end

    
  def rpc_update( session )
    reply( :update, :name_date => "#{Date.today.strftime('%y%m')}")
  end
end
