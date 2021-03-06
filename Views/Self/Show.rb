# Allows to add, modify and delete persons

class SelfShow < View
  def layout
    set_data_class :Persons
    @order = 20
    @update = true

    gui_hbox do
      show_block :address, :width => 150
      show_button :save

      gui_vbox :nogroup do
        show_str :new_password
        show_button :change_password

        show_button :logout
      end
    end

    dputs(5) { "#{@layout.inspect}" }
  end

  def rpc_button(session, name, data)
    dputs(3) { "Pressed button #{name} with #{data.inspect}" }
    person = session.owner
    case name
      when 'change_password'
        person.password = data['new_password']
      when 'save'
        person.data_set_hash(data)
      when 'logout'
        return reply('reload')
    end
    return nil
  end

  def rpc_update(session)
    if session.owner
      reply(:empty_nonlists) +
          reply(:update, session.owner.to_hash)
    else
      log_msg :SelfShow, 'Got empty session.owner, reloading'
      reply(:reload)
    end
  end
end
