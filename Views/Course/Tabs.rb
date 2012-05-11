class CourseTabs < View
  def layout
    gui_vboxg :nogroup do
      show_list_single :courses, "Entities.Courses.list_courses", :callback => true
      show_button :new_course, :delete
    end
  end

  def rpc_button_new_course( session, args )

  end

  def rpc_button_delete( session, args )

  end

  def rpc_list_choice( session, name, args )
    dputs 2, "New choice #{name} - #{args.inspect}"

    reply( 'pass_tabs', [ "list_choice", name, args ] )
  end
end