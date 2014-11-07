# Allows to add, modify and delete persons

class PersonAdmin < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 30

    gui_vboxg do
      gui_group do
        gui_hboxg :nogroup do
          gui_hboxg :nogroup do
            gui_fields do
              show_str_ro :login_name
              show_str_ro :person_id
              show_block :admin
              show_arg :permissions, :flexheight => 1
            end
          end
          gui_vbox :nogroup do
            gui_vbox :nogroup do
              show_field :groups
            end
          end
        end
        show_button :save
      end

    end
  end

  def rpc_button_save(session, data)
    dputs(3) { "#{data.inspect}" }
    person = Persons.match_by_person_id(data['person_id'])
    rep = reply(:empty_fields)
    if person
      log_msg :persons, "#{session.owner.login_name} saves #{data.inspect}"
      Persons.save_data(data)
      person.update_accounts
      rep += update_form_data(person)
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
      if p = Persons.match_by_login_name(data['persons'].flatten[0])
        #reply( :empty_fields, [:internet_none] ) +
        reply(:empty_fields, [:permissions, :groups]) +
            reply(:update, :permissions => Permission.list.sort) +
            reply(:update, :groups => eval(Persons.get_value(:groups).list)) +
            reply(:update, p)
      end
    end
  end

  def update(session)
    {:your_account_total_due => session.owner.account_total_due}
  end
end
