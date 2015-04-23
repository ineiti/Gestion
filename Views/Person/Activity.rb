class PersonActivity < View
  include PrintButton

  def layout
    @update = true
    @visible = false
    @order = 140

    @functions_need = [:cashbox]

    gui_vbox do
      gui_vbox :nogroup do
        show_table :activities, :headings => %w( Activity Paid Start End ),
                   :width => 300
      end
      gui_hbox :nogroup do
        show_print :add_act, :delete, :print_activity
      end

      gui_window :add_activity do
        gui_hboxg do
          gui_vboxg :nogroup do
            show_entity_activities_all :activity, :single, :name, :callback => true
          end
          gui_vboxg :nogroup do
            show_block_ro :show
            show_date :date_start
            show_button :close, :pay
          end
        end
      end

      gui_window :printing do
        show_html :msg_print
        show_button :close
      end
    end
  end

  def rpc_update( session )
    reply_print( session )
  end

  def get_person(p)
    (p.class == Array) ? get_person(p.first) : p
  end

  def rpc_button_pay(session, data)
    return unless data._activity
    student = Persons.match_by_login_name(get_person(data._persons))
    ActivityPayments.pay(data._activity, student, session.owner,
                         Date.from_web(data._date_start))
    reply(:window_hide) +
        rpc_list_choice_persons(session, data)
  end

  def rpc_button_add_act(session, data)
    reply(:window_show, :add_activity) +
        reply(:empty, :activity) +
        reply(:update, :activity => Activities.listp_name)
  end

  def rpc_button_delete(session, data)
    data._activities.length > 0 or return
    act = ActivityPayments.match_by_activitypayment_id(data._activities.first)
    if act.movement.account_src == act.person_cashed.account_due
      act.movement.delete
      act.delete
      rpc_list_choice_persons(session, data)
    else
      reply(:window_show, :printing)+
          reply(:update, :msg_print => 'Ce mouvement est déjà comptabilisé')
    end
  end

  def rpc_list_choice_activity(session, data)
    reply(:update, data._activity.to_hash)
  end

  def rpc_list_choice_persons(session, data)
    return unless student = Persons.match_by_login_name(get_person(data._persons))

    act_table = ActivityPayments.for_user(student).collect { |act|
      [act.activitypayment_id, [act.activity.name, act.activity.cost,
                                act.date_start, act.date_end]]
    }.sort { |a, b| a[3] <=> b[3] }.reverse
    reply(:empty, :activities) +
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
    files = OpenPrint.pdf_nup_duplex([act.print])
    if lp_cmd
      System.run_bool("#{lp_cmd} #{files.pop}")
      System.run_bool("#{lp_cmd} #{files.pop}")
      rep += reply(:window_show, :printing) +
          reply(:update, :msg_print => "Printing is finished on #{lp_cmd.sub(/.* /,'')}")
    else
      rep += reply(:window_show, :printing) +
          reply(:update, :msg_print => 'Click on one of the links:<ul>' +
              files.collect { |r| "<li><a target='other' href=\"#{r}\">#{r}</a></li>" }.join('') +
              '</ul>')
    end

    return rep
  end
end

