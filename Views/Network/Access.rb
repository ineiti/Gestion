class NetworkAccess < View
  include VTListPane

  def layout
    @order = 90
    @functions_need = [:internet, :network_pro]

    set_data_class :AccessGroups

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :groups, :name
        show_button :new, :delete
      end
      gui_vbox :nogroup do
        show_field :name
        show_field :action
        show_field :priority
        show_field :limit_day_mo
        show_list_single :access_times_view

        show_button :save, :add_time, :delete_time
      end
      gui_vbox :nogroup do
        show_list_single :members_view
        show_str :login_name
        show_button :add_member, :delete_member
      end
    end
  end

  def update_access_times(group)
    ats = if group.access_times and (group.access_times.size > 0)
            group.access_times
          else
            ['Always']
          end
    reply(:empty, [:access_times_view]) +
        reply(:update, :access_times_view => ats)
  end

  def update_members(group)
    if group and group.members
      members = group.members.collect { |m|
        if member = Persons.match_by_login_name(m)
          name = member.full_name
          name.to_s == 0 and name = member.login_name
          [member.login_name, name]
        else
          []
        end
      }
    else
      members = []
    end
    members.size == 0 and members = [[0, 'All users']]
    return reply(:empty_update, :members_view => members)
  end

  def rpc_button_new(session, data)
    reply(:empty_nonlists, [:access_times_view]) +
        update_members(nil) +
        vtlp_update_list(session)
  end

  def rpc_button_add_time(session, data)
    rep = rpc_button_save(session, data)
    if group = AccessGroups.match_by_name(data._name)
      if not group.access_times
        group.access_times = []
      end
      time = data['time'].join(';')
      if not group.access_times.index(time)
        group.access_times += [time]
      end
      rep += update_access_times(group)
    end
    return rep
  end

  def rpc_button_delete_time(session, data)
    if (group = AccessGroups.match_by_accessgroup_id(data._groups[0])) and
        (time = data['access_times_view'][0]) and
        group.access_times
      group.access_times.delete(time)
      update_access_times(group)
    end
  end

  def rpc_button_add_member(session, data)
    if (person = Persons.match_by_login_name(data._login_name)) and
        (group = AccessGroups.match_by_accessgroup_id(data._groups[0]))
      dputs(3) { "Found person #{person.inspect} and group #{group.inspect}" }
      if not group.members
        group.members = []
      end
      if not group.members.index person.login_name
        group.members.push person.login_name
      end
      update_members(group) +
          reply(:empty, :login_name)
    end
  end

  def rpc_button_delete_member(session, data)
    if (person = Persons.match_by_login_name(data._members_view[0])) and
        (group = AccessGroups.match_by_accessgroup_id(data._groups[0]))
      group.members.delete person.login_name
      update_members(group)
    end
  end

  alias_method :rpc_button_save_old, :rpc_button_save

  def rpc_button_save(session, data)
    rpc_button_save_old(session, data) +
        reply(:empty, [:access_times_view, :members_view])
  end

  alias_method :rpc_list_choice_old, :rpc_list_choice

  def rpc_list_choice(session, name, data)
    case name
      when /groups/
        ret = rpc_list_choice_old(session, name, data)
        if group = AccessGroups.match_by_accessgroup_id(data._groups[0])
          ret += update_access_times(group) + update_members(group)
        else
          ret += reply(:empty, :access_times_view)
        end
        return ret
    end
  end
end
