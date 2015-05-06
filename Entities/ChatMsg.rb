class ChatMsgs < Entities
  def setup_data
    value_time :time
    value_str :msg
    value_entity_person :center
    value_str :login

    @max_msgs ||= 200
    @static._client_times |= {}
  end

  # Pushes a message to the server and returns eventual new messages
  # tr holds the following keys:
  # center: hash with {login, pass} keys
  # person: login-name of person
  # msg: the message written
  #
  # It returns the results from icc_msg_pull
  def icc_msg_push(tr)
    return nil unless ConfigBase.functions.index(:course_server)
    center = Persons.check_login(tr._center._login, tr._center._pass)
    if center && center.has_permission?(:center)
      new_msg(tr._person, tr._msg, center)
    else
      return "Error: center #{center.inspect} has wrong password or is not a center"
    end
    icc_msg_pull(tr)
  end

  # Gets new messages sinces last call
  # tr holds the following keys:
  # center: hash with {login, pass} keys
  def icc_msg_pull(tr)
    return 'Error: not a server here' unless ConfigBase.has_function?(:course_server)
    center = Persons.check_login(tr._center._login, tr._center._pass)
    if !center || !center.has_permission?(:center)
      return "Error: center #{center.inspect} has wrong password or is not a center"
    end
    @static._client_times ||= {}
    last_time = @static._client_times[center.login_name] || Time.new(2000,1,1)
    @static._client_times[center.login_name] = Time.now
    search_all.select{|msg| msg.time > last_time && msg.center != center}.collect{|msg|
      msg.to_hash.merge(center: msg.center.login_name)
    }
  end

  def new_msg(person, msg, center = Persons.center)
    create(time: Time.now, msg: msg, center: center,
           login: person)
    if @data.length > @max_msgs
      get_data_instance(@data.keys.first).delete
    end
  end

  def show_list
    search_all_.collect{|cm| "#{cm.time.strftime('%H:%M')} - #{cm.login}: #{cm.msg}"}.
        join("\n")
  end
end