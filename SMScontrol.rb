require 'network'
require 'helperclasses'
require 'erb'

module SMScontrol
  attr_accessor :modem, :state_now, :state_goal, :state_error, :state_traffic,
                :max_traffic
  extend self
  include Network
  extend HelperClasses::DPuts

  @modem = Modem.present

  @state_now = MODEM_DISCONNECTED
  @state_goal = MODEM_CONNECTED
  @send_status = false
  @state_error = 0
  @phone_main = 62154352
  @state_traffic = 0
  @max_traffic = 3000000

  def is_connected
    @state_now == MODEM_CONNECTED
  end

  def state_to_s
    "#{@state_now}-#{@state_goal}-#{@state_error}-#{@state_traffic}"
  end

  def interpret_commands(msg)
    ret = []
    msg.sub(/^cmd:/i, '').split("::").each { |cmdstr|
      log_msg :'SMS.rb', "Got command-str #{cmdstr.inspect}"
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
    old = @state_now
    @state_now = @modem.connection_status
    traffic = @modem.traffic_stats
    dputs(3) { "#{traffic.inspect}" }
    @state_traffic = traffic._rx.to_i + traffic._tx.to_i
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
      @modem.sms_send(@phone_main, interpret_commands("cmd:status").join("::"))
      @send_status = false
    end
    @modem.sms_list.each { |sms|
      SMSs.create(sms)
      log_msg :'SMS.rb', "Working on SMS #{sms.inspect}"
      case sms._Content
        when /^cmd:/i
          if ret = interpret_commands(sms._Content)
            log_msg :'SMS.rb', "Sending to #{sms._Phone} - #{ret.inspect}"
            @modem.sms_send(sms._Phone, ret.join('::'))
          end
        when /votre.*solde/i
          @modem.traffic_reset
          make_connection
          log_msg :SMScontrol, "Airtel - make connection"
          @send_status = true
        when /160.*cfa/i
          log_msg :'SMS.rb', "Getting internet-credit"
          @modem.sms_send(100, "internet")
        when /310.*cfa/i
          log_msg :'SMS.rb', "Getting internet-credit"
          @modem.sms_send(200, "internet")
        when /810.*cfa/i
          log_msg :'SMS.rb', "Getting internet-credit"
          @modem.sms_send(1111, "internet")
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
          log_msg :'SMS.rb', "Making connection"
          @send_status = true
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
