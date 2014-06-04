require 'network'
require 'helperclasses'

module SMScontrol
  attr_accessor :modem, :state_now, :state_goal, :state_error, :state_traffic
  extend self
  include Network
  extend HelperClasses::DPuts

  @modem = Modem.present

  @state_now = MODEM_DISCONNECTED
  @state_goal = MODEM_DISCONNECTED
  @state_error = 0
  @state_traffic = nil
  @max_traffic = 3000000
  @phone_main = 99836457

  def state_to_s
    "#{@state_now}-#{@state_goal}-#{@state_error}-#{@state_traffic}"
  end

  def interpret_commands(msg)
    ret = []
    msg.sub(/^cmd:/, '').split("::").each { |cmd|
      log_msg :SMScontrol, "Got command #{cmd.inspect}"
      case /^ *(.+?) *$/.match( cmd )[1].downcase
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
    @state_goal = MODEM_CONNECTED
    @state_error = 0
  end

  def check_connection
    return unless @modem
    @state_now = @modem.connection_status
    if @state_goal != @state_now
      if @state_now == MODEM_CONNECTION_ERROR
        @state_error += 1
        @modem.connection_stop
	sleep 2
        #if @state_error > 5
        #  @state_goal = MODEM_DISCONNECTED
        #end
      end
      if @state_goal == MODEM_DISCONNECTED
        @modem.connection_stop
      elsif @state_goal == MODEM_CONNECTED
        @modem.connection_start
      end
    elsif @state_now == MODEM_CONNECTED
      traffic = @modem.traffic_stats
      dputs(3){ "#{traffic.inspect}" }
      @state_traffic = traffic._rx.to_i + traffic._tx.to_i
      if @state_traffic > @max_traffic
        @state_goal = MODEM_DISCONNECTED
        check_connection
      end
    else
      @state_error = 0
    end
  end

  def check_sms
    return unless @modem
    @modem.sms_list.each { |sms|
      log_msg :SMScontrol, "Working on SMS #{sms.inspect}"
      case sms._Content
        when /^cmd:/i
          if ret = interpret_commands(sms._Content)
            log_msg :SMScontrol, "Sending to #{sms._Phone} - #{ret.inspect}"
            @modem.sms_send(sms._Phone, ret.join('::'))
          end
        when /160.*cfa/i
	  log_msg :SMScontrol, "Getting internet-credit"
	  @modem.sms_send( 100, "internet" )
        when /souscription reussie/i
          @modem.traffic_reset
          make_connection
	  log_msg :SMScontrol, "Making connection"
	  @modem.sms_send( @phone_main, interpret_commands( "cmd:status" ).join("::") )
      end
      @modem.sms_delete(sms._Index)
    }
  end
end
