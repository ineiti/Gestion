class CourseTabs < View
  def layout
    @order = 20
    @update = true

    gui_window :error do
      show_html "<h1>You're not allowed to do that</h1>"
      show_button :close
    end
    
    gui_vboxg :nogroup do
      show_list_single :courses, :callback => true
      show_button :delete
    end
  end
  
  def rpc_update( session )
    reply( :empty, [ :courses ] ) +
    reply( :update, :courses => Entities.Courses.list_courses(session))
  end

  def rpc_button_delete( session, args )
    if not session.can_view( 'CourseAdd' )
      reply( "window_show", "error")
    end
  end

  def rpc_list_choice( session, name, args )
    dputs( 2 ){ "New choice #{name} - #{args.inspect}" }

    reply( 'pass_tabs', [ "list_choice", name, args ] )
  end
end
