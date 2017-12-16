=begin
This module allows for charging the internet-credit of a person. You can also
add a new person
=end

class CashboxCredit < View
  def layout
    set_data_class :Persons
    @order = 30
    @update = true
    @functions_need = [:internet, :internet_cyber]

    gui_hbox do
      gui_vbox :nogroup do
        show_str :search
        show_entity_person :person, :single, :login_name, :callback => true
        show_button :search_person, :add_person
      end

      gui_vbox :nogroup do
        show_int :credit_add
        show_str_ro :login_name
        show_str_ro :full_name
        show_int_ro :internet_credit
        show_button :add_credit
      end

      gui_window :win_add do
        show_str :full_name
        show_button :win_add_person, :close
      end

    end
  end

  def rpc_button_add_person(session, data)
    reply(:window_show, :win_add) +
        reply(:empty, :full_name)
  end

  def rpc_button_win_add_person(session, data)
    ret = reply(:window_hide)
    person = if data._full_name.to_s.length > 0
               Persons.create(complete_name: data._full_name)
             end
    person.permissions = %w(default internet)
    ret + (person ? rpc_button_search_person(session, search: person.login_name) : [])
  end

  def rpc_button_search_person(session, data)
    return reply(:empty, :person) unless data._search.length > 2
    results = Persons.search_in(data._search, 20)
    if results.size > 0
      reply(:empty_update, :person => results.collect { |r| r.to_list_id(session.owner) } +
                             [results.first.person_id])
    end
  end

  def rpc_button_add_credit(session, data)
    dputs(3) { "Adding credit #{data.inspect}" }
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