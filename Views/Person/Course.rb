# Allows to add, modify and delete persons

class PersonCourse < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 45
    @functions_need = [:courses]

    gui_vbox do
      show_str_ro :first_name
      show_str_ro :family_name
      show_list_single :courses
      show_button :add, :delete
      
      gui_window :new_course do
        show_list_single :courses_available, 'Entities.Courses.list_courses'
        show_button :add_course, :close
      end
    end
  end
  
  def rpc_update( session )
    reply( :empty, [:courses] )
  end
  
  def rpc_list_choice( session, name, args )
    dputs( 0 ){ "args is #{args.inspect}" }
    ret = reply( :empty, [:courses] )
    if name == "persons" and args['persons']
      p = Entities.Persons.match_by_login_name( args['persons'].flatten[0] )
      if p
        ret += reply( :update, :courses => Entities.Courses.list_courses_for_person( p ) ) +
          update_form_data( p )
      end
    end
    ret
  end

  def rpc_button_add( session, args )
    if args['persons'].flatten.length > 0
      reply( :empty_only, [ :courses_available ] ) +
        reply( :update, :courses_available => 
          ( Entities.Courses.list_courses - 
            Entities.Courses.list_courses_for_person( args['persons'].flatten[0] ) ) ) +
        reply( :window_show, :new_course )
    end
  end
  
  def rpc_button_delete( session, args )
    if ca = args['courses'] and ca.length > 0
      c = Entities.Courses.match_by_id( ca[0] )
      c.students.delete( args['persons'].flatten[0] )
    end
    rpc_list_choice( session, 'persons', args )    
  end
  
  def rpc_button_add_course( session, args )
    if ca = args['courses_available'] and ca.length > 0
      c = Entities.Courses.match_by_id( ca[0] )
      c.students.push args['persons'].flatten[0]
    end
    reply( :window_hide ) +
      rpc_list_choice( session, 'persons', args )
  end
  
  def rpc_button_close( session, args )
    reply( :window_hide )
  end

end
