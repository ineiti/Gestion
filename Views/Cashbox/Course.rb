# Allows for adding cash to a specific course

class CashboxCourse < View
  def layout
    @order = 0
    @update = true
    
    gui_hboxg do
      gui_vbox :nogroup do
        show_entity_course :courses, :single, :name,
          :flexheight => 1, :callback => true, :width => 100
      end
      gui_vbox :nogroup do
        show_entity_person_lazy :students, :single, :full_name,
          :flexheight => 1, :callback => true, :width => 150
      end
      gui_vbox do
        show_date :payment_date
        show_int :cash
        show_str :remark
        show_str :receit_id
        show_button :pay
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
      reply( :update, :payment_date => @date_pay.strftime( "%d.%m.%Y") )
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
      log_msg "course-payment", "Paying #{data._cash} to #{data._students.full_name} of " +
        "#{data._courses.name}"
      dputs(3){"Owner is #{session.owner.inspect}"}
      dputs(3){"Putting from #{session.owner.account_due.path} to " +
          "#{data._courses.entries}"
      }
      Movements.create( "For student #{data._students.login_name}:" +
          "#{data._students.full_name}", data._payment_date, data._cash.to_f / 1000,
        session.owner.account_due, data._courses.entries )
    end
    rpc_list_choice_students( session, data )
  end
  
  def rpc_update( session )
    reply( :empty, :students )
  end

end