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
    dputs(3){"Data is #{data.inspect}"}
    if data._cash.to_i != 0
      dputs(3){ "Paying #{data._cash} to #{data._students.full_name} of " +
          "#{data._courses.name}"}
    end
    rpc_list_choice_students( session, data )
  end
  
  def rpc_update( session )
    reply( :empty, :students )
  end

end