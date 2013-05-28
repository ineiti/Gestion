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

  def rpc_button_new_course( session, data )
    dputs( 3 ){ "session: #{session} - data: #{data.inspect}" }
    
    course = Courses.create_ctype( data['ctype'], data['name_date'], session.owner )

    reply( "parent",
      View.CourseTabs.rpc_update( session ) +
        reply( "update", { :courses => [ course.course_id ] } ) ) +
      reply( "switch_tab", :CourseModify )
  end

    
  def rpc_update( session )
    reply( :update, :name_date => "#{Date.today.strftime('%y%m')}")
  end
end
