class CashboxCredit < View
  def layout
    set_data_class :Persons
    @order = 30
    @update = true
    @functions_need = [:internet]

    gui_hbox do
      gui_vbox :nogroup do
        show_str :search
        show_entity_person :person, :single, :login_name, :callback => true
        show_button :search_person
      end

      gui_vbox :nogroup do
        show_int :credit_add
        show_str_ro :login_name
        show_str_ro :full_name
        show_int_ro :internet_credit
        show_button :add_credit
      end
    end
  end

  def rpc_button_search_person(session, data)
    return reply(:empty, :person) unless data._search.length > 2
    results = Persons.search_in(data._search, 20)
    reply(:empty_update, :person => results.collect { |r| r.to_list_id } +
                           [results.first.person_id])
  end

  def rpc_button_add_credit(session, data)
    dputs(3) { 'Adding credit' }
    rep = []
    if person = Persons.add_internet_credit(session, data)
      rep = reply(:update, :credit_add => '') +
          reply(:update, :internet_credit => person.internet_credit)
    end
    rep + rpc_update(session)
  end

  def rpc_update(session)
    super(session) +
        reply(:parent, reply(:focus, :search))
  end

  def rpc_list_choice_person(session, data)
    dputs(2) { "Got data: #{data.inspect}" }
    if data._person
      reply(:empty_update, data._person) +
          reply(:focus, :credit_add)
    end
  end
end