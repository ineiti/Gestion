# Allows for adding cash to a specific course

class CashboxCourse < View
  def layout
    @order = 20
    @update = true
    @functions_need = [:cashbox]
    
    gui_hboxg do
      gui_vbox :nogroup do
        show_entity_course_lazy :courses, :single, :name,
          :flexheight => 1, :callback => true, :width => 100
      end
      gui_vbox :nogroup do
        show_entity_person_lazy :students, :single, :full_name,
          :flexheight => 1, :callback => true, :width => 300
        #        show_str :full_name
        #        show_button :add_student
      end
      gui_vbox :nogroup do
        show_table :payments, :headings => [ :Date, :Money, :Sum ],
          :widths => [100, 75, 75], :height => 200,
          :columns => [0, :align_right, :align_right]
        show_date :payment_date
        show_int :cash
        show_str :remark
        show_str :receit_id
        show_list_drop :old_cash, "%w( No Yes )"
        show_button :pay, :delete
      end
      
      gui_window :error do
        show_html :msg
        show_button :close
      end
    end
    
    @date_pay = Date.today
  end
  
  def rpc_list_choice_courses( session, data )
    reply( :empty, :students ) +
      reply( :update, :students => data._courses.list_students( true ) )
  end
  
  def rpc_list_choice_students( session, data )
    reply( :empty ) +
      reply( :update, :payment_date => @date_pay.strftime( "%d.%m.%Y") ) +
      reply( :update, :payments => 
        data._courses.student_payments(data._students.login_name))
  end
  
  def rpc_button_pay( session, data )
    if data._payment_date
      @date_pay = Date.parse( data._payment_date )
    end
    
    [ [session.owner.account_due, "No account for #{session.owner.full_name}"],
      [data._courses != [], "Chose a course first"],
      [data._students != [], "Chose a student first"],
      [data._courses.entries != [], "Course has no account attached"],
      [data._cash.to_i != 0, "Enter an amount"]].each{|t,msg|
      dputs(3){"Testing #{t.inspect} - #{msg}"}
      t or return reply( :window_show, :error ) +
        reply( :update, :msg => msg )
    }
      
    dputs(3){"Data is #{data.inspect}"}
    if data._cash.to_i != 0
      log_msg "course-payment", "#{session.owner.login_name} pays #{data._cash} " +
        "to #{data._students.full_name} of #{data._courses.name}"
      Movements.create( "For student #{data._students.login_name}:" +
          "#{data._students.full_name}", 
        @date_pay.strftime( "%Y-%m-%d" ), data._cash.to_f / 1000,
        session.owner.account_due, data._courses.entries )
      if session.owner.has_permission?( :admin ) && 
          data._old_cash.first == "Yes"
        log_msg "course-payment", "Oldcash - doing reverse, too"
        Movements.create( "old_cash for #{data._students.login_name}", 
          @date_pay.strftime( "%Y-%m-%d" ), data._cash.to_f / 1000,
          data._courses.entries, session.owner.account_due )
      end
    end
    rpc_list_choice_students( session, data )
  end

  def rpc_button_add_student( session, data )
    if ( name = data._full_name ).to_s.length > 0 &&
        ( course = data._courses )
      Persons.create_add_course( data._full_name, session.owner, course )
      rpc_list_choice_courses( session, data )
    end
  end
  
  def rpc_update( session )
    if owner = session.owner
      reply_visible( owner.has_permission?( :admin ), :old_cash )
    else
      []
    end +
      reply( :empty, :students ) +
      reply( :empty, :courses ) +
      reply( :update, :courses => Courses.list_courses_entries )
  end
  
  def rpc_button_delete( session, data )
    if ( gid = data._payments.first ).to_s.length > 0
      if mov = Movements.match_by_global_id( gid )
        log_msg "cashbox_course", "Deleting movement #{mov.inspect}"
        mov.delete
        rpc_list_choice_students( session, data )
      end
    end
  end
end
