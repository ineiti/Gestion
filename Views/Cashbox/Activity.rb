class CashboxActivity < View
  include PrintButton

  def layout
    @update = true
    @order = 140

    @functions_need = [:cashbox]

    gui_hboxg do
      gui_vboxg :nogroup do
        show_entity_activity :activities, :list, :name, :flexheight => 1, :width => 200,
                             :callback => true
        show_block_ro :show
      end
      gui_vboxg :nogroup do
        gui_vboxg :nogroup do
          show_entity_person_lazy :students, :multi, :full_name,
                                  :flexheight => 1, :callback => true, :width => 300
          show_str :full_name
        end
        gui_hbox :nogroup do
          show_print :new_student, :existing_student, :signed_up_students,
                     :print_student
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
        show_button :close
      end
    end
  end

  def rpc_button_pay_act(session, data)
    return unless (data._activities and data._students.length == 1)
    ActivityPayments.pay(data._activities, data._students.first, session.owner,
                         Date.from_web(data._date_start))
    reply(:window_hide)
  end

  def rpc_button_delete(session, data)
    return unless (data._activities and data._students.length == 1 and
        data._table_activities.length == 1)
    if data._activities.movement.account_src == data._activities.person_cashed.account_due
      data._activities.movement.delete
      data._activities.delete
      rpc_list_choice_persons(session, data)
    else
      reply(:window_show, :printing)+
          reply(:update, :msg_print => 'Ce mouvement est déjà comptabilisé')
    end
  end

  def rpc_button_signed_up_students(session, data)
    #dp data._activities
    #dp ActivityPayments.search_by_activity( data._activities )
    reply(:empty_only, :students) +
        reply(:update, :students =>
            ActivityPayments.search_by_activity(data._activities).collect { |ap|
              ap.person_paid.to_list
            })
  end

  def rpc_button_new_student(session, data)

  end

  def rpc_button_existing_student(session, data)
    Persons.search_in(data._full_name, :students)
  end

  def rpc_list_choice_activities(session, data)
    reply(:update, data._activities.first.to_hash) +
        rpc_button_signed_up_students(session, data)
  end

  def rpc_list_choice_persons(session, data)
    return unless student = Persons.match_by_login_name(get_person(data._persons))

    act_table = ActivityPayments.for_user(student).collect { |act|
      [act.activitypayment_id, [act.activity.name, act.activity.cost,
                                act.date_start, act.date_end]]
    }.sort { |a, b| a[3] <=> b[3] }.reverse
    reply(:empty_only, :activities) +
        reply(:update, :activities => act_table) +
        reply(:update, :date_start => Date.today.to_web)
  end

  def rpc_button_print_activity(session, data)
    return unless student = Persons.match_by_login_name(get_person(data._persons))
    act =
        if data._activities.length == 0
          ActivityPayments.for_user(student).sort { |a, b| a.date_start <=> b.date_start }.
              reverse.first
        else
          ActivityPayments.match_by_activitypayment_id(data._activities.first)
        end

    rep = rpc_print(session, :print_activity, data)
    lp_cmd = cmd_printer(session, :print_activity)
    files = OpenPrint.print_nup_duplex([act.print])
    if lp_cmd
      %x[ #{lp_cmd} #{files.pop} ]
      %x[ #{lp_cmd} #{files.pop} ]
      rep += reply(:window_show, :printing) +
          reply(:update, :msg_print => "Printing is finished on #{lp_cmd.sub(/.* /, '')}")
    else
      rep += reply(:window_show, :printing) +
          reply(:update, :msg_print => 'Click on one of the links:<ul>' +
              files.collect { |r| "<li><a target='other' href=\"#{r}\">#{r}</a></li>" }.join('') +
              '</ul>')
    end

    return rep
  end
end

