class CourseStats < View
  def layout
    set_data_class :Courses
    @update = true
    @order = 100
    #@visible = false

    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_block :accounting
        end
      end
      show_block :account
      show_arg :entries, :width => 400
      show_button :save
    end
  end

  def rpc_button_save( session, data )
    if course = Courses.match_by_course_id( data._courses.first )
      dputs(3){"Found course #{course.name} with data #{data.inspect}"}
      data.delete( 'students' )
      course.data_set_hash( data )
    end
  end

  def rpc_list_choice( session, name, args )
    dputs( 3 ){ "rpc_list_choice with #{name} - #{args.inspect}" }
    if name == "courses" and args['courses'].length > 0
      course_id = args['courses'][0]
      dputs( 3 ){ "replying for course_id #{course_id}" }
      course = Courses.match_by_course_id(course_id)
      reply("empty", [:students]) +
        update_form_data( course ) +
        reply("update", {:courses => [course_id] } )
    end
  end
end
