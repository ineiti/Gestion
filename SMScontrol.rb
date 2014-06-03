require 'network'

module SMScontrol
  attr_accessor :modem, :state_now, :state_goal, :state_error, :state_traffic
  extend self
  include Network

  @modem = Modem.present

  @state_now = MODEM_DISCONNECTED
  @state_goal = MODEM_DISCONNECTED
  @state_error = 0
  @state_traffic = nil

  def state_to_s
    "#{@state_now}-#{@state_goal}-#{@state_error}-#{@state_traffic}"
  end

  def interpret_commands(msg)
    ret = []
    msg.sub(/^cmd:/, '').split("::").each { |cmd|
      case cmd
        when /^status$/
          disk_usage = %x[ df -h / | tail -n 1 ].gsub(/ +/, ' ').chomp
          ret.push "#{state_to_s} :: #{disk_usage} :: #{Time.now}"
        when /^connect/
          @state_goal = MODEM_CONNECTED
        when /^disconnect/
          @state_goal = MODEM_DISCONNECTED
        when /^bash:/
          ret.push %x[ #{cmd.sub(/^bash:/, '')}]
        when /^ping/
          ret.push 'pong'
      end
    }
    ret.length == 0 ? nil : ret
  end

  def make_connection
    @modem.traffic_reset
    @state_goal = MODEM_CONNECTED
  end

  def check_connection
    return unless @modem
    @state_now = @modem.connection_status
    if @state_goal != @state_now
      if @state_goal == MODEM_DISCONNECTED
        @modem.connection_stop
      elsif @state_now == MODEM_CONNECTION_ERROR
        @state_error += 1
        if @state_error > 5
          @state_goal = MODEM_DISCONNECTED
        end
      elsif @state_goal == MODEM_CONNECTED
        if @state_now == MODEM_DISCONNECTED
          @modem.connection_start
        end
      end
    elsif @state_now == MODEM_CONNECTED
      traffic = @modem.traffic_stats
      p traffic
      @state_traffic = traffic.rx + traffic.tx
      if @state_traffic > @max_traffic
        @state_goal = MODEM_DISCONNECTED
        check_connection
      end
    end
  end

  def check_sms
    return unless @modem
    @modem.sms_list.each { |sms|
      puts "Working on SMS #{sms.inspect}"
      case sms._Content
        when /^cmd:/
          if ret = interpret_commands(sms._Content)
            @modem.sms_send(sms._Number, ret.join('::'))
          end
        when /CFA/
          make_connection
      end
      @modem.sms_delete(sms._Index)
    }
  end
end