class ChatMsgs < Entities
  def setup_data
    value_time :time
    value_str :msg
    value_entity_person :center
    value_str :login

    @max_msgs ||= 200
    @static._client_times ||= {}
  end

  # Pushes a message to the server and returns eventual new messages
  # tr holds the following keys:
  # center: hash with {login, pass} keys
  # person: login-name of person
  # msg: the message written
  #
  # It returns the results from icc_msg_pull
  def icc_msg_push(tr)
    #return 'Error: no course_server' unless ConfigBase.functions.index(:course_server)
    center = Persons.check_login(tr._center._login, tr._center._pass)
    if center && center.has_permission?(:center)
      new_msg(tr._person, tr._msg, center)
    else
      return "Error: center #{center.inspect} has wrong password or is not a center"
    end
    icc_msg_pull(tr)
  end

  # Gets new messages since last call
  # tr holds the following keys:
  # center: hash with {login, pass} keys
  def icc_msg_pull(tr)
    #return 'Error: not a server here' unless ConfigBase.has_function?(:course_server)
    center = Persons.check_login(tr._center._login, tr._center._pass)
    if !center || !center.has_permission?(:center)
      return "Error: center #{center.inspect} has wrong password or is not a center"
    end
    @static._client_times ||= {}
    last_time = @static._client_times[center.login_name] || Time.new(2000, 1, 1)
    @static._client_times[center.login_name] = Time.now
    search_all.select { |msg| msg.time > last_time && msg.center != center }.collect { |msg|
      msg.to_hash.merge(center: msg.center.login_name)
    }
  end

  def center_hash
    return {} unless center = Persons.center
    {center: {login: center.login_name, pass: center.password_plain}}
  end

  def new_msg(person, msg, center = nil)
    create(time: Time.now, msg: msg, center: center,
           login: center ? "#{person}@#{center.login_name}" : person)
    log_msg :ChatMsgs, "#{person} says - #{msg}"
    if @data.length > @max_msgs
      get_data_instance(@data.keys.first).delete
    end
  end

  def new_msg_send(person, msg)
    new_msg(person, msg)
    if ConfigBase.has_function?(:remote_chat)&&
        ConfigBase.server_url.to_s.length > 0
      log_msg :ChatMsgs, "Sending msg from #{person} to server"
      ICC.get(:ChatMsgs, :msg_push, args: center_hash.merge(person: person, msg: msg))
    end
  end

  def show_list(max = 100)
    search_all_.reverse[0...max].collect { |cm|
      "#{cm.time.strftime('%H:%M')} - #{cm.login}: #{cm.msg}"
    }.join("\n")
  end

  def pull_server_start(wait = 60)
    return unless Persons.center
    @thread = Thread.new {
      loop do
        ret = ICC.get(:ChatMsgs, :msg_pull, args: center_hash)
        dputs(2) { "Got reply #{ret.inspect}" }
        if ret._code =~ /^error/i
          dputs(0) { "Error #{ret._msg} while fetching chat-messages" }
        else
          ret._msg.each { |m|
            dputs(2) { "Got message #{m.inspect}" }
            new_msg("#{m._login}@#{m._center}", m._msg)
          }
        end

        sleep wait
      end
    }
  end

  def pull_server_kill
    @thread.kill
    @thread.join
  end

  def load
    super
    ChatMsgs.search_all.each{|cm|
      cm.time = Time.parse(cm.time)
    }
  end
end
