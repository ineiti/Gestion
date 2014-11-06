# Allows to add, modify and delete persons

class PersonModify < View
  include PrintButton

  def layout
    set_data_class :Persons
    @update = true
    @order = 10

    gui_hbox do
      gui_vbox do
        gui_fields do
          show_str_ro :login_name, :width => 150
          show_str_ro :person_id
          show_block :address
        end
        gui_hbox :nogroup do
          show_print :save, :print_student
        end
      end

      gui_vbox :nogroup do
        show_str :new_password
        show_str_ro :password_plain
        show_html :not_allowed
        show_button :change_password
      end

      gui_window :printing do
        show_html :msg_print
        show_button :close
      end

    end
  end

  def rpc_button(session, name, data)
    dputs(2) { "Pressed button #{name} with #{data.inspect}" }
    person = Persons.match_by_person_id(data['person_id'])

    rep = [] #reply( :empty )
    owner = session.owner
    if person
      case name
        when 'change_password'
          if owner.has_all_rights_of(person) ||
              (owner.permissions.index(:center) &&
                  person.login_name =~ /^#{owner.login_name}_/)
            person.password = data['new_password']
            rep = reply(:empty, [:new_password]) +
                reply(:update, :password_plain => person.password_plain)
          end
        when 'save'
          log_msg :persons, "#{session.owner.login_name} saves #{data.inspect}"
          rep = reply(:update, Persons.save_data(data))
        when 'print_student'
          rep = rpc_print(session, name, data)
          person.lp_cmd = cmd_printer(session, name)
          file = person.print
          if file.class == String
            rep += reply(:window_show, :printing) +
                reply(:update, :msg_print => 'Click to download:<ul>' +
                    "<li><a target='other' href=\"#{file}\">#{file}</a></li></ul>")
          end
        when 'close'
          rep = reply(:window_hide)
      end
    end
    rep + rpc_update(session)
  end

  def rpc_find(session, field, data)
    rep = Persons.find(field, data)
    if not rep
      rep = {"#{field}" => data}
    end
    update_layout(session) +
        reply(:update, rep) + rpc_update(session)
  end

  def rpc_list_choice(session, name, data)
    if name == 'persons'
      dputs(2) { "Got data: #{data.inspect}" }
      if data['persons'][0] and
          p = Persons.match_by_login_name(data['persons'].flatten[0])
        can_change = session.owner.has_all_rights_of(p)
        change_pwd = [:new_password, :password_plain, :change_password].collect { |f|
          reply(can_change ? :unhide : :hide, f)
        }.flatten + reply(can_change ? :hide : :unhide, :not_allowed) +
            reply(:update, :not_allowed => "<b>Vous n'avez pas le droit<br>" +
                'de changer ce mot de passe</b>')
        dputs(4) { "change_pwd is #{change_pwd.inspect}" }
        reply(:empty_all) + reply(:update, p) + reply(:update, update(session)) +
            reply(:focus, :credit_add) + reply_print(session) + change_pwd
      end
    end
  end

  def update(session)
    if person = session.owner
      {:your_account_total_due => person.account_total_due}
    end
  end

  def rpc_update(session)
    super(session) +
        reply(:parent, reply(:focus, :search)) +
        reply_print(session) +
        (session.owner.permissions.index('center') ?
            reply(:hide, :print_student) : [])
  end
end
