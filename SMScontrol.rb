require 'network'
require 'helperclasses'
require 'erb'

module SMScontrol
  attr_accessor :modem, :state_now, :state_goal, :state_error, :state_traffic,
                :max_traffic
  extend self
  include Network
  extend HelperClasses::DPuts

  UNKNOWN = -1

  @modem = Modem.present

  @state_now = MODEM_DISCONNECTED
  @state_goal = UNKNOWN
  @send_status = false
  @state_error = 0
  @phone_main = 99836457
  @state_traffic = 0
  @max_traffic = 3000000
  @sms_injected = []
  @provider = :Tigo

  def is_connected
    @state_now == MODEM_CONNECTED
  end

  def state_to_s
    "#{@state_now}-#{@state_goal}-#{@state_error}-#{@state_traffic}"
  end

  def inject_sms(content, phone = '1234',
      date = Time.now.strftime('%Y-%m-%d %H:%M:%S'), index = -1)
    new_sms = {:Content => content, :Phone => phone,
               :Date => date, :Index => index}
    @sms_injected.push(new_sms)
    dputs(2) { "Injected #{new_sms.inspect}: #{@sms_injected.inspect}" }
  end

  def interpret_commands(msg)
    ret = []
    msg.sub(/^cmd:/i, '').split("::").each { |cmdstr|
      log_msg :SMS, "Got command-str #{cmdstr.inspect}"
      cmd, attr = /^ *([^ ]*) *(.*) *$/.match(cmdstr)[1..2]
      case cmd.downcase
        when /^status$/
          disk_usage = %x[ df -h / | tail -n 1 ].gsub(/ +/, ' ').chomp
          ret.push "#{state_to_s} :: #{disk_usage} :: #{Time.now}"
        when /^connect/
          @modem.traffic_reset
          make_connection
        when /^disconnect/
          @state_goal = MODEM_DISCONNECTED
        when /^bash:/
          ret.push %x[ #{attr}]
        when /^ping/
          ret.push 'pong'
        when /^sms/
          number, text = attr.split(";", 2)
          @modem.sms_send(number, text)
      end
    }
    ret.length == 0 ? nil : ret
  end

  def make_connection
    @state_goal = MODEM_CONNECTED
    @state_error = 0
  end

  def check_connection
    @modem = Modem.present
    return unless @modem

    traffic = @modem.traffic_stats
    dputs(3) { "#{traffic.inspect}" }
    @state_traffic = traffic._rx.to_i + traffic._tx.to_i
    if @state_goal == UNKNOWN
      @state_goal = @state_traffic < @max_traffic ?
          MODEM_CONNECTED : MODEM_DISCONNECTED
    end

    old = @state_now
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
        if @state_traffic > @max_traffic
          @state_goal = MODEM_DISCONNECTED
        else
          @modem.connection_start
        end
      end
    else
      @state_error = 0
    end
    if old != @state_now
      if @state_now == MODEM_CONNECTED
        Network::connection_up
      elsif old == MODEM_CONNECTED
        Network::connection_down
      end
    end
  end

  def check_sms
    return unless @modem
    if @send_status
      @modem.sms_send(@phone_main, interpret_commands('cmd:status').join('::'))
      @send_status = false
    end
    sms = @modem.sms_list.concat(@sms_injected)
    @sms_injected = []
    dputs(3) { "SMS are: #{sms.inspect}" }
    sms.each { |sms|
      SMSs.create(sms)
      log_msg :SMS, "Working on SMS #{sms.inspect}"
      if sms._Content =~ /^cmd:/i
        if ret = interpret_commands(sms._Content)
          log_msg :SMS, "Sending to #{sms._Phone} - #{ret.inspect}"
          @modem.sms_send(sms._Phone, ret.join('::'))
        end
      else
        case @provider
          when :Airtel
            case sms._Content
              when /votre.*solde/i
                @modem.traffic_reset
                make_connection
                log_msg :SMScontrol, 'Airtel - make connection'
                @send_status = true
            end
          when :Tigo
            case sms._Content
              when /160.*cfa/i
                log_msg :SMS, 'Getting internet-credit'
                @modem.sms_send(100, 'internet')
              when /310.*cfa/i
                log_msg :SMS, 'Getting internet-credit'
                @modem.sms_send(200, 'internet')
              when /810.*cfa/i
                log_msg :SMS, 'Getting internet-credit'
                @modem.sms_send(1111, 'internet')
              when /souscription reussie/i
                @modem.traffic_reset
                case sms._Content
                  when /100/
                    @max_traffic = 3000000
                  when /200/
                    @max_traffic = 6000000
                  when /800/
                    @max_traffic = 30000000
                end
                if Date.today.wday % 6 == 0
                  @max_traffic *= 2
                end
                make_connection
                log_msg :SMS, "Making connection"
                @send_status = true
            end
        end
      end
      @modem.sms_delete(sms._Index)
    }
  end
end

class SMSinfo < RPCQooxdooPath
  def self.parse(method, path, query)
    dputs(3) { "Got #{method} - #{path} - #{query}" }
    ERB.new(File.open('Files/smsinfo.erb') { |f| f.read }).result(binding)
  end
end
