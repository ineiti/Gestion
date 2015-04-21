class ChatMsgs < Entities
  def setup_data
    value_time :time
    value_str :msg
    value_entity_person :center
    value_str :login

    @max_msgs ||= 50
    @static._client_times |= {}
  end

  # Pushes a message to the server and returns eventual new messages
  def icc_msg_push(tr)
    return nil unless ConfigBase.functions.index(:course_server)
  end

  # Gets new messages sinces last call
  def icc_msg_pull(tr)
    return nil unless ConfigBase.functions.index(:course_server)
  end

  def new_msg(person, msg)
    create(time: Time.now, msg: msg, center: Persons.center,
           login: person.login_name)
    if @data.length > @max_msgs
      get_data_instance(@data.keys.first).delete
    end
  end

  def show_list
    search_all_.collect{|cm| "#{cm.time.strftime('%H:%M')} - #{cm.login}: #{cm.msg}"}.
        join("\n")
  end
end