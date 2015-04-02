=begin rdoc
Allows to edit and add users with regard to InternetClass, so they only can
use a certain amount of bytes per day.

TODO: make a working add-button
=end

class InternetClassUsers < View
  def layout
    @order = 300
    @update = true

    gui_hbox do
      gui_vbox :nogroup do
        show_str :search_str
        show_entity_person :persons, :single, :login_name, callback: true
        show_button :search #, :add
      end
      gui_vbox :nogroup do
        show_entity_internetClass_empty_all :iclass, :drop, :name
        show_date :start
        show_int :duration
        show_button :save
      end

      gui_window :add_win do
        show_str :add_full_name
        show_str :add_login_name
        show_entity_internetClass_empty_all :add_iclass, :drop, :name
        show_date :add_date
        show_int :add_duration
        show_button :add_user
      end
    end
  end

  def rpc_button_add(session, data)
    reply(:window_show)
  end

  def rpc_update(session)
    return unless t = Network::Captive.traffic
    list = t.traffic.collect { |h, _k|
      [h, t.get_day(h, 1).inject(:+)]
    }.sort_by { |t| t[1] }.reverse[0..10].collect { |t|
      p = Persons.match_by_login_name t[0]
      p.to_list_id(false)
    }
    reply(:empty_update, persons: list)
  end

  def rpc_button_search(session, data)
    return unless (str = data._search_str).length > 2
    list = Persons.data.select { |k, v|
      "#{v._login_name} #{v._first_name} #{v._family_name}" =~ /#{str}/ }
    return reply(:empty, :persons) unless list.length > 0
    list = list.sort_by { |k, v| (v._login_name <=> str).to_i.abs }[0..19].
        collect { |k, v| Persons.get_data_instance(k) }.
        collect { |p| [p.person_id, "#{p.full_name} - #{p.login_name}"] }
    reply(:empty_update, persons: list + [list.first[0]])
  end

  def rpc_list_choice_persons(session, data)
    ret = reply(:empty, %w(start duration)) +
        reply(:update, iclass: [0])
    ip = InternetPersons.match_by_person(data._persons)
    return ret unless ip
    ret + reply(:update, ip.to_hash)
  end

  def rpc_button_save(session, data)
    ip = InternetPersons.match_by_person(data._persons.person_id) ||
        InternetPersons.create(person: data._persons)
    ip.data_set_hash(data)
  end

end