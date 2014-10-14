class SelfEmail < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 100
    @functions_need = [:network, :email]
    @elements = %w( email acc_remote acc_pass acc_proto acc_port acc_supp )

    gui_vbox do
      show_str_ro :login_name
      show_str :email, :width => 300
      show_block :email_account
      show_button :save
    end
  end

  def rpc_update(session, client = nil)
    person = session.owner
    reply(:empty_fields) +
        reply(:update, :login_name => person.login_name) +
        reply(:update, Hash[*@elements.collect { |e|
          [e.to_sym, person.data_get(e)] }.flatten(1)])
  end


  def rpc_button_save(session, data)
    person = session.owner
    @elements.each { |d|
      person.data_set(d, data[d])
    }
    Persons.update_fetchmailrc
  end

end
