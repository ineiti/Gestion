class CourseAdd < View
  def layout
    set_data_class :Courses
    @update = true
    @order = 50

    gui_hbox do
      gui_vbox :nogroup do
        show_list_drop :name_base, "Entities.Courses.list_name_base"
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
    course.set_data( data )
    end
  end

  def rpc_button_new_course( session, data )
    dputs 3, "session: #{session} - data: #{data.inspect}"

    name = "#{data['name_base'][0]}_#{data['name_date']}"
    course = Courses.find_by_name( name )
    if name =~ /_.+/
      if not course
        # Search latest course of this type and copy description and contents
        last_course = Entities.Courses.search_by_name("#{name.gsub( /_.*/, '' )}_.*").sort{|a,b|
          a.name <=> b.name
        }.last
        course = Courses.create( {:name => name })
        if last_course
          dputs 2, "Found course #{last_course.name} and copying description and contents"
        course.description = last_course.description
        course.contents = last_course.contents
        end
      end
    end

    reply( "parent",
      View.CourseTabs.rpc_update( session ) +
      reply( "update", { :courses => [ course.course_id ] } ) ) +
    reply( "switch_tab", :CourseModify )
  end

end
