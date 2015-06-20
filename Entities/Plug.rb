class Plugs < Entities
  def setup_data
    value_str :internal_id
    value_str :fixed_id
    value_str :center_name
    value_str :center_id
    value_str :center_city
    value_str :ip_local
    value_date :installation
    value_str :telephone
    value_str :credit
    value_str :internet_left
    value_list_drop :model, '%w(DreamPlug08 DreamPlug10 Smileplug
      Cubox-i1 Cubox-i2x Cubox-i4)'
    value_int :storage_size

    Network::Device.add_observer(self)
    update('add', Network::Device.search_dev({uevent: {driver: 'option'}}).first)
  end

  def update(op, dev = nil)
    return unless ConfigBase.has_function?(:plug_admin)
    dputs(2) { "Updating with operation #{op} and device #{dev}" }
    if op =~ /add/ && dev && dev.instance_variable_defined?(:@serial_sms_new)
      dev.serial_sms_new.push(Proc.new { |sms| new_sms(sms) })
    end
  end

  def new_sms(sms)
    dputs_func
    dputs(2) { "Found new sms #{sms.inspect}" }
    search_all_.each { |p|
      # Match for incomplete, but existing telephone number. Make sure that
      # +235999999 matches 999999, in both ways
      p1 = p.telephone.to_s.gsub(/[^0-9]/, '')
      p2 = sms._number.gsub(/[^0-9]/, '')
      dputs(3) { "Phone-numbers are _#{p1}_ and _#{p2}_" }
      if p1.length > 0 && (p1 =~ /#{p2}$/ || p2 =~ /#{p1}$/)
        p.new_sms(sms)
      end
    }
  end

  def listp_center
    Plugs.search_all_.collect{|p| [p.plug_id, p.center_name]}
  end
end

class Plug < Entity
  def send_cmd_sms(*cmds)
    return unless telephone.to_s.length > 0 &&
        !$MobileControl.operator_missing?
    msg = "cmd: #{cmds.join('::')}"
    add_stat(msg, :sms, :send)
    $MobileControl.device.sms_send(telephone.to_s, msg)
  end

  def send_credit(amount)
    return unless telephone.to_s.length > 0 &&
        !$MobileControl.operator_missing?
    add_stat(amount.to_s, :credit, :send)
    $MobileControl.operator.credit_send(telephone.to_s, amount)
  end

  def new_sms(sms)
    add_stat(sms._msg, :sms, :rcv)
    log_msg :Plug, "Got new sms #{sms.inspect}"
    case sms._msg
      when /^stat: (.*): (.*) :: (.*) :: (.*)/
        host, state, disk, time = $1, $2, $3, $4
        _, _, _, internet, credit = state.split(':')
        dputs(2) { "Host #{host} has state #{state}" }
        self.internal_id = host
        if internet != 'noop'
          self.internet_left = internet.gsub(/[^0-9]/, '').to_i * 1_000_000
          self.credit = credit
          dputs(2) { "Host #{host} has #{internet} Bytes and #{self.credit} left" }
        end
      else
        log_msg :Plut, "Unknown message from #{host}"
    end
  end

  def add_stat(msg, type, dir)
    PlugStats.create(time: Time.now, msg: msg, msg_type: [type],
                     msg_dir: [dir], plug: self)
  end
end

class PlugStats < Entities
  def setup_data
    value_time :time
    value_str :msg
    value_list :msg_type, '%w( sms email rpc credit )'
    value_list :msg_dir, '%w( send rcv )'
    value_entity :plug
  end
end