class CourseStats < View
  def layout
    set_data_class :Courses
    @update = true
    @order = 40

    gui_hbox do
      gui_vbox :nogroup do
        show_block :accounting
        show_button :save
      end
    end
  end

  def rpc_button_save( session, data )
    course = Courses.match_by_name( data['name'] )
    if course
      # BUG: they're already saved, don't save it again
      data.delete( 'students' )
    course.data_set_hash( data )
    end
  end
end
