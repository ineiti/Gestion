class CourseTabs < View
  def layout
    @order = 20
    @update = false

    gui_window :course do
      show_list_drop :name_base, "Entities.Courses.list_name_base"
      show_str :name_date
      show_button :new_course, :close
    end
    
    gui_vboxg :nogroup do
      show_list_single :courses, "Entities.Courses.list_courses", :callback => true
      show_button :add_course, :delete
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

    reply("empty", [:courses]) +
    reply( "update", {:courses => Entities.Courses.list_courses}) +
    reply( "update", { :courses => [ course.course_id ] }) +
    reply( "window_hide" )
  end

  def rpc_button_add_course( session, data)
    reply( "window_show", "course" )
  end

  def rpc_button_delete( session, args )

  end

  def rpc_list_choice( session, name, args )
    dputs 2, "New choice #{name} - #{args.inspect}"

    reply( 'pass_tabs', [ "list_choice", name, args ] )
  end
end