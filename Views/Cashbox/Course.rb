# Allows for adding cash to a specific course

class CashboxCourse < View
  def layout
    @order = 10
    @update = true
    @functions_need = [:cashbox, :accounting_courses]

    gui_hboxg do
      gui_vbox :nogroup do
        show_entity_course :courses, :single, :name,
                           :flexheight => 1, :callback => true, :width => 100
      end
      gui_vbox :nogroup do
        show_entity_person :students, :single, :full_name,
                           :flexheight => 1, :callback => true, :width => 300
        show_str :full_name
        show_button :add_student
      end
      gui_vbox :nogroup do
        show_table :payments, :headings => [:Date, :Money, :Rest],
                   :widths => [100, 75, 75], :height => 200,
                   :columns => [0, :align_right, :align_right]
        show_date :payment_date
        show_int :cash
        show_str :remark
        show_str :receit_id
        show_list_drop :old_cash, '%w( No Yes )'
        show_button :pay, :delete, :move
      end

      gui_window :error do
        show_html :msg
        show_button :close
      end

      gui_window :win_move do
        show_entity_person :move_students, :drop, :full_name, :width => 300
        show_button :close, :do_move
      end
    end

    @date_pay = Date.today
  end

  def rpc_list_choice_courses(session, data)
    reply(:empty_fields, :students) +
        reply(:update, :students => data._courses.list_students(true))
  end

  def rpc_list_choice_students(session, data)
    reply(:empty, %w(cash remark receit_id)) +
        reply(:update, :payment_date => @date_pay.strftime('%d.%m.%Y')) +
        reply(:update, :payments =>
            data._courses.student_payments(data._students.login_name))
  end

  def rpc_button_pay(session, data)
    if data._payment_date
      @date_pay = Date.parse(data._payment_date)
    end

    [[session.owner.account_due, "No account for #{session.owner.full_name}"],
     [data._courses != [], 'Chose a course first'],
     [data._students != [], 'Chose a student first'],
     [data._courses.entries != [], 'Course has no account attached'],
     [data._cash.to_i != 0, 'Enter an amount']].each { |t, msg|
      dputs(3) { "Testing #{t.inspect} - #{msg}" }
      t or return reply(:window_show, :error) +
          reply(:update, :msg => msg)
    }

    dputs(3) { "Data is #{data.inspect}" }
    if data._cash.to_i != 0
      data._courses.payment(session.owner, data._students, data._cash, @date_pay,
                            session.owner.has_permission?(:admin) && data._old_cash.first == 'Yes')
    end
    rpc_list_choice_students(session, data)
  end

  def rpc_button_add_student(session, data)
    if (name = data._full_name).to_s.length > 0 &&
        (course = data._courses)
      Persons.create_add_course(data._full_name, session.owner, course)
      rpc_list_choice_courses(session, data)
    end
  end

  def rpc_button_move(session, data)
    if data._students && data._courses
      reply(:empty, :move_students) +
          reply(:window_show, :win_move) +
          reply(:update, :move_students => data._courses.list_students(true))
    end
  end

  def rpc_button_do_move(session, data)
    if (src = data._students) &&
        (dst = data._move_students) &&
        src != dst &&
        data._courses
      dputs(3) { "Moving student #{src.inspect}, #{dst.inspect}" }
      data._courses.move_payment(src.login_name, dst.login_name)
    end
    reply(:window_hide) +
        rpc_list_choice_students(session, data)
  end

  def rpc_update(session)
    if owner = session.owner
      reply_visible(owner.has_permission?(:admin), :old_cash)
    else
      []
    end +
        reply(:empty_fields, :students) +
        reply(:empty_fields, :courses) +
        reply(:update, :courses => Courses.list_courses_entries)
  end

  def rpc_button_delete(session, data)
    if (gid = data._payments.first).to_s.length > 0
      if mov = Movements.match_by_global_id(gid)
        log_msg 'cashbox_course', "Deleting movement #{mov.inspect}"
        date, value = mov.date, mov.value
        mov.delete
        user, id = gid.match(/(.*)-(.*)/)[1..2]
        ngid = [user, (id.to_i + 1).to_s].join("-")
        # If the next movement starts with "old_cash" and has same date
        # and value, we suppose they go together
        if mov = Movements.match_by_global_id(ngid) and
            mov.desc =~ /^old_cash/ and mov.date == date and
            mov.value == value
          log_msg 'cashbox_course', "Found old_cash at #{mov.inspect}"
          mov.delete
        end
        rpc_list_choice_students(session, data)
      end
    end
  end
end
