class PersonTabs < View
  def layout
    @order = 10
    @update = true
    @persons_total = Persons.data.count

    gui_vbox :nogroup do
      show_str :search
      show_list_single :persons, '[]', :flexheight => 1, :callback => true
      show_button :start_search, :delete, :add

      gui_window :add_person do
        show_str :complete_name, :width => 150
        show_str :login_prop
        #show_block :address
        show_button :add_person, :close
      end

      gui_window :error do
        show_html :info
        show_button :close
      end

      gui_window :win_confirm_delete do
        show_html :delete_txt
        show_button :confirm_delete, :close
      end
    end
  end

  def rpc_update(session)
    super(session)
    #+ rpc_callback_search(session, {}, false)
  end

  def rpc_button_start_search(session, args)
    rpc_callback_search(session, args)
  end

  def rpc_button_delete(session, args)
    if session.can_view(:FlagDeletePerson)
      if (p_login = args._persons) and
          (p = Persons.match_by_login_name(p_login[0]))
        dputs(3) { "Found person #{p.inspect} - #{p.class.name}" }
        return reply(:window_show, :win_confirm_delete) +
            reply(:update, :delete_txt => 'Are you sure you want to delete user<br>' +
                             "#{p.login_name}:#{p.full_name} ?")
      end
    end
  end

  def rpc_button_confirm_delete(session, args)
    if session.can_view(:FlagDeletePerson)
      if (p_login = args._persons) and
          (p = Persons.match_by_login_name(p_login[0]))
        dputs(3) { "Found person #{p.inspect} - #{p.class.name}" }
        begin
          log_msg :Persons, "User #{session.owner.login_name} deletes #{p.login_name}"
          p.delete
        rescue IsNecessary => who
          return reply(:window_hide) +
              reply(:window_show, :error) +
              reply(:update, :info => "Course #{who.for_course.name} " +
                               "still needs #{p.login_name}")
        end
      end
    end
    reply(:window_hide) +
        rpc_callback_search(session, args)
  end

  def rpc_update_view(session, args = nil)
    login_prop = session.can_view(:FlagAdminLoginProp) ? :unhide : :hide
    super(session, args) +
        reply(:focus, :search) +
        reply(session.can_view(:FlagPersonDelete) ? :unhide : :hide, :delete) +
        reply(session.can_view(:FlagPersonAdd) ? :unhide : :hide, :add) +
        reply(login_prop, :login_prop) +
        reply(:fade_in, :parent)
  end

  def rpc_list_choice(session, name, args)
    dputs(2) { "args is #{args.inspect}" }
    dputs(2) { "New choice #{name} - #{args['persons']}" }

    if name == 'persons' and args and args['persons']
      reply(:pass_tabs, ['list_choice', name, {:persons => [args._persons]}]) +
          reply(:fade_in, :parent_child)
    else
      []
    end
  end

  def rpc_callback_search(session, data, do_list_choice = true)
    dputs(2) { "Got data: #{data.inspect}" }

    s = data._search

    center = session.owner.permissions.index('center') ?
        session.owner.login_name : nil
    result = Persons.search_in(s, center: center)

    ret = reply(:empty, :persons)

    if result.length > 0
      ret += reply(:update,
                   :persons => result.collect { |p|
                     p.to_list(p.simple) },
                   :search => s)
      if do_list_choice
        ret += reply(:update, :persons => [result[0].login_name])
      end
    else
      ret += reply(:fade_in, :parent) +
          reply(:child, reply(:empty_nonlists))
    end

    ret + reply(:focus, :search)
  end

  def rpc_autofill(session, args)
    ret = []
    if args['persons'] and args['persons'].length > 0
      p = Persons.match_by_login_name(args['persons'][0])
      if args['search']
        ret += rpc_callback_search(session, args, false)
      else
        ret += reply(:update, :persons => [p.to_list]) +
            reply(:update, :search => p.login_name)
      end
      ret += reply(:update, :persons => [p.login_name])
    elsif args['search']
      ret += rpc_callback_search(session, args)
    end
    ret
  end

  def rpc_button_close(session, data)
    reply(:window_hide)
  end

  def rpc_button_add(session, data)
    reply(:window_show, :add_person) +
        reply(:empty, [:complete_name, :login_prop]) +
        reply(:hide, [:family_name, :first_name]) +
        reply(:focus, :complete_name)
  end

  def rpc_button_add_person(session, data)
    data.to_sym!
    dputs(3) { "Pressed button accept with #{data.inspect}" }
    person = Persons.create_person(data._complete_name, session.owner,
                                   data._login_prop)
    #person.data_set_hash(data.reject { |k, v|
    #  k =~ /(family_name|first_name|login_name|person_id)/ })

    reply(:window_hide) +
        rpc_callback_search(session, 'search' => person.login_name)
    #reply( :child, reply( :switch_tab, :PersonModify ) ) +
  end

end
