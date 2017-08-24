class CashboxActivity < View
  include PrintButton

  def layout
    @update = true
    @order = 15

    @functions_need = [:activities]

    gui_hboxg do
      gui_vboxg :nogroup do
        show_entity_activity_all :activities, :single, :name, :flexheight => 1, :width => 200,
                                 :callback => true
        show_block_ro :show
      end
      gui_vboxg :nogroup do
        gui_vboxg :nogroup do
          show_entity_person :students, :single, :full_name,
                             :flexheight => 1, :callback => true, :width => 300
          show_str :full_name
          show_button :search_student, :new_student, :signed_up_students
          # show_print :print_activity
        end
      end
      gui_vboxg :nogroup do
        gui_vbox :nogroup do
          show_table :table_activities, :headings => %w( Start End )
          show_date :date_start
        end
        show_button :pay_act, :delete
      end

      gui_window :printing do
        show_html :msg_print
        show_int_hidden :step
        show_button :print_next, :close
      end
    end
  end

  def rpc_update(session)
    # reply_print(session) +
    reply(:update, :date_start => Date.today.to_web)
  end

  def rpc_button_pay_act(session, data)
    return unless (data._activities and data._students)
    # dp data._students
    ActivityPayments.pay(data._activities, data._students, session.owner,
                         Date.from_web(data._date_start))
    reply(:window_hide) +
        rpc_list_choice_students(session, data)
  end

  def rpc_button_delete(session, data)
    return unless (data._activities and data._students and
        data._table_activities.length == 1)

    act = ActivityPayments.match_by_activitypayment_id(data._table_activities.first)
    if act.movement.account_src == act.person_cashed.account_due
      act.movement.delete
      act.delete
      rpc_list_choice_students(session, data)
    else
      reply(:window_show, :printing)+
          reply(:update, :msg_print => 'Ce mouvement est déjà comptabilisé')
    end
  end

  def rpc_button_signed_up_students(session, data)
    reply(:empty, :students) +
        reply(:update, :students =>
                         ActivityPayments.search_by_activity(data._activities).collect { |ap|
                           ap.person_paid and ap.person_paid.to_list_id(session.owner)
                         }.compact.sort_by { |i| i[1] })
  end

  def rpc_button_new_student(session, data)
    return unless (data._full_name || data._full_name.to_s.length > 0)
    student = Persons.create({first_name: data._full_name})
    student.permissions = %w(student internet)
    data._full_name = student.login_name
    rpc_button_search_student(session, data) +
        reply(:update, students: [student.person_id])
  end

  def rpc_button_search_student(session, data)
    return unless (data._full_name || data._full_name.to_s.length > 0)
    reply(:empty_update, students: Persons.search_in(data._full_name).
                           collect { |p| p.to_list_id(session.owner) })
  end

  def rpc_list_choice_activities(session, data)
    reply(:empty_nonlists_update, data._activities.to_hash) +
        rpc_button_signed_up_students(session, data)
  end

  def rpc_list_choice_students(session, data)
    return reply(:empty, %w(full_name table_activities)) unless data._students

    act_table = ActivityPayments.for_user(data._students).collect { |act|
      [act.activitypayment_id, [act.date_start, act.date_end]]
    }.sort { |a, b| a[1] <=> b[1] }.reverse
    reply(:empty_update, :table_activities => act_table) +
        reply(:update, :date_start => Date.today.to_web)
  end

  def rpc_button_print_activity_steps(session, data)
    ret = reply(:callback_button, :print_activity_steps)
    var = session.s_data._print_activity
    dputs(3) { "Doing with data #{var.inspect} step is #{var._step.inspect}" }
    case var._step
      when 1
        dputs(3) { 'Showing prepare-window' }
        var._students = var._activities.collect { |a| a.person_paid.login_name }
        ret += reply(:window_show, :printing) +
            reply(:update, :msg_print => 'Preparing students: <br><br>' +
                             var._students.each_slice(5).collect { |s| s.join(', ') }.
                                 join(',<br>')) +
            reply(:hide, :print_next)
      when 2
        dputs(3) { 'Printing pdfs' }
        files = var._activities.collect { |act| act.print }
        var._pages = OpenPrint.pdf_nup_duplex(files, 'activity_cards')
        cmd = cmd_printer(session, :print_activity)
        dputs(3) { "Command is #{cmd} with pages #{var._pages.inspect}" }
        if not cmd
          ret = reply(:window_show, :printing) +
              reply(:update, :msg_print => 'Click on one of the links:<ul>' +
                               var._pages.collect { |r| "<li><a target='other' href=\"#{r}\">#{r}</a></li>" }.join('') +
                               '</ul>')
          var._step = 9
        elsif var._pages.length > 0
          ret = reply(:window_show, :printing) +
              reply(:update, :msg_print => 'Impression de la page face en cours pour<ul>' +
                               "<li>#{var._students.join('</li><li>')}</li></ul>" +
                               "<br>Cliquez sur 'suivant' pour imprimer les pages arrières") +
              reply(:unhide, :print_next)
          cmd += " #{var._pages[0]}"
          dputs(3) { "Printing-cmd is #{cmd.inspect}" }
          System.run_bool(cmd)
        else
          var._step = 9
        end
      when 3
        cmd = cmd_printer(session, :print_activity)
        dputs(3) { "Command is #{cmd} with pages #{var._pages.inspect}" }
        ret = reply(:window_show, :printing) +
            reply(:update, :msg_print => 'Impression de la page face arrière en cours<ul>' +
                             "<li>#{var._students.join('</li><li>')}</li></ul>") +
            reply(:hide, :print_next)
        cmd += " -o outputorder=reverse #{var._pages[1]}"
        dputs(3) { "Printing-cmd is #{cmd.inspect}" }
        System.run_bool(cmd)
      when 4..10
        dputs(3) { 'Hiding' }
        ret = reply(:window_hide)
      else
        dputs(3) { "Oups - step is #{var._step.inspect}" }
    end

    var._step += 1
    session.s_data[:print_activity] = var
    dputs(3) { "Ret is #{ret.inspect}" }
    return ret
  end

  def rpc_button_print_activity(session, data)
    # dp "removed"
    return nil
    return unless data._students.length >= 1
    acts = data._students.collect { |s|
      if data._table_activities.length == 0
        ActivityPayments.for_user(s).sort { |a, b| a.date_start <=> b.date_start }.
            reverse.first
      else
        ActivityPayments.match_by_activitypayment_id(data._table_activities.first)
      end
    }

    ret = rpc_print(session, :print_activity, data)
    session.s_data._print_activity = {step: 1, activities: acts}
    return ret + rpc_button_print_activity_steps(session, data)
  end

  def rpc_button_print_next(session, data)
    rpc_button_print_activity_steps(session, data)
  end

end

