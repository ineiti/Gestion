=begin rdoc
=== Internet

This module links the following external parts:
* Network::Device - to handle internet-captive devices
* Monitor::Traffic - to watch individual traffic from users

To use it, call the #setup method, which will list all devices and start
listening for new ones.
=end

# Holds the different type of users with regard to internet.
# TODO: add limit_class and limit_course to +type+
class InternetClasses < Entities
  def setup_data
    value_str :name
    value_int :limit
    value_list_drop :type, '%w(unlimited limit_daily_mo limit_daily_min)'
  end

  def migration_1_raw(i)
    i._type == ['limit_daily'] and i._type = ['limit_daily_mo']
    i._limit = i._limit_mo
  end
end

# Represents one usage-type
class InternetClass < Entity
  # Checks whether a given user is in limits of InternetClasses and thus
  # allowed to use the internet
  def in_limits?(host, today = Date.today)
    return true if type == ['unlimited']
    return true unless t = Network::Captive.traffic
    t.get_day(host, 1, today.to_time).flatten[0..1].inject(:+) < limit.to_i * 1_000_000
  end
end

class InternetPersons < Entities
  def setup_data
    value_entity_person :person
    value_entity_internetClasses :iclass
    value_date :start
    value_int :duration
  end
end

class InternetPerson < Entity
  # checks whether that person has an active reference to #InternetClasses
  def is_active?(today = Date.today)
    duration.to_i == 0 ||
        (start.to_s != '' && (Date.from_web(start) + duration.to_i >= today))
  end

  # checks whether a person is active and in limits
  def in_limits?(today = Date.today)
    is_active?(today) && iclass.in_limits?(person.login_name, today)
  end
end

module Internet
  attr_accessor :operator, :device
  extend self
  include Network

  @operator = nil

  # Gets all devices and adds an observer for new devices. Also sets up
  # traffic-tables for users, loading if some already exist
  def setup
    #dputs_func
    @traffic_save = Statics.get(:GestionTraffic)
    if (cd = ConfigBase.captive_dev).to_s.length > 0 &&
        cd != 'false' && ConfigBase.has_function?(:internet_captive)
      @device = nil
      Device.add_observer(self)

      if ConfigBase.captive_dev != 'simul'
        dev = Device.search_dev({uevent: {interface: ConfigBase.captive_dev}})
        if dev.length == 0
          log_msg :Internet, "Couldn't find #{ConfigBase.captive_dev}"
          Device.list
          return
        end
        update('add', dev.first)
      end
    end
    dputs(4) { "@traffic is #{@traffic}" }
  end

  # Whenever a new device or a new operator is detected, this function
  # updates the internal variables.
  def update(operation, dev = nil)
    case operation
      when /del/
        if @device == dev
          log_msg :Internet, "Lost device #{@device}"
          @device.delete_observer(self)
          @device = nil
          Captive.accept_all
        end
      when /add/
        d = dev.dev
        if !@device && d._uevent && d._uevent._interface == ConfigBase.captive_dev
          @device = dev
          @device.add_observer(self)
          @operator = @device.operator
          @operator and Captive.setup(@device, @traffic_save.data_str)
          log_msg :Internet, "Got new device #{@device} - #{ConfigBase.captive_dev}"
        else
          log_msg :Internet, "New device #{dev} that doesn't match #{ConfigBase.captive_dev}"
        end
      when /operator/
        @operator = @device.operator
        Captive.setup(@device, @traffic_save.data_str)
        log_msg :Internet, "Got new operator #{@operator}"
    end
  end

  # Scans all connected users and deduces money from all connected, non-free
  # users. If there is not enough money left, it kicks the user.
  def take_money
    #dputs_func
    return unless @operator

    Captive.cleanup
    Captive.users_connected.each { |u|
      HelperClasses::System.rescue_all do
        dputs(3) { "User is #{u}" }
        cost = @operator.user_cost_now.to_i

        dputs(3) { "ISP is #{@operator.name} and conn_type is "+
            "#{@operator.connection_type}" }
        user = Persons.match_by_login_name(u)
        if user
          dputs(3) { "Found user #{u}: #{user.full_name}" }
          if not (ag = AccessGroups.allow_user_now(u))[0]
            log_msg 'take_money', "Kicking user #{u} because of accessgroups: #{ag[1]}"
            user_disconnect user.login_name
          elsif self.free(user)
            dputs(2) { "User #{u} goes free" }
            Captive.user_keep(user.login_name, ConfigBase.keep_idle_free.to_i)
          elsif @device.connection_status == Device::CONNECTED
            dputs(3) { "User #{u} will pay #{cost}" }
            if user.internet_credit.to_i >= cost
              dputs(3) { "Taking #{cost} internet_credits from #{u} who has #{user.internet_credit}" }
              user.internet_credit = user.internet_credit.to_i - cost
            else
              log_msg 'take_money', "User #{u} has not enough money left - kicking"
              user_disconnect user.login_name
            end
          end
        else
          dputs(0) { "Error: Captive said #{u} is connected, but couldn't find that user!" +
              " Users connected: #{Captive.users_connected.inspect}" }
        end
      end
    }
  end

  # Scan for all active courses (date_start <= date_now <= date_end) for a
  # specific +user+, which should be of type #Persons
  def active_course_for(user)
    # We want an exact match, so we put the name between ^ and $
    courses = Courses.search_by_students("^#{user.login_name}$")
    if courses
      dputs(3) { "Courses : #{courses.inspect}" }
      courses.each { |c|
        dputs(3) { "Searching course #{c}" }
        if c.name and c.start and c.end
          dputs(3) { "Searching course for #{user.full_name}" }
          dputs(3) { [c.name, c.start, c.end].inspect }
          begin
            c_start = Date.strptime(c.start, '%d.%m.%Y')
            c_end = Date.strptime(c.end, '%d.%m.%Y')
          rescue
            c_start = c_end = Date.new
          end
          if c_start <= Date.today and Date.today <= c_end
            return true
          end
        end
      }
    end
    return false
  end

  # Decides whether a person is allowed to surf for free, depending on:
  # - ConfigBase.allow_free ('all' - 'false' - 'true')
  # - permissions (FlagInternetFree and internet_free_staff)
  # - freesurf-group
  # - courses (date between :start and :end and internet_free_course)
  # - InternetPersons, where the different allowed traffics might be stored
  def free(user)
    #dputs_func
    case ConfigBase.allow_free
      when /all/
        return true
      when /false/
        return false
    end
    if user.class != Person
      user = Persons.match_by_login_name(user)
      dputs(4) { "Found user #{user.login_name}" }
    end
    login = user.login_name
    if user
      dputs(3) { "Searching groups for user #{login}: #{user.groups.inspect}" }
      if user.groups && user.groups.index('freesurf')
        dputs(3) { "User #{login} is on freesurf" }
        return true
      end

      if ConfigBase.has_function?(:internet_free_staff) &&
          Permission.can_view(user.permissions, 'FlagInternetFree')
        dputs(3) { "User #{login} has FlagInternetFree" }
        return true
      end

      if ConfigBase.has_function?(:internet_free_course) &&
          self.active_course_for(user)
        dputs(3){"User #{login} is free for a course"}
        return true
      end

      if (ip = InternetPersons.match_by_person(user)) && ip.iclass
        dputs(3){"User #{login} has internetpersons #{ip.in_limits?}"}
        return ip.in_limits?
      end

      if ic = ConfigBase.iclass_default
        dputs(3){"User #{login} falls into default : #{ic.in_limits?(login)}"}
        return ic.in_limits?(login)
      end
    end
    dputs(3) { 'Found nothing' }
    return false
  end

  # Fetches new traffic and saves the actual traffic in Statics
  def update_traffic
    return unless Captive.traffic
    Captive.traffic.update
    @traffic_save.data_str = Captive.traffic.to_json
  end

  # Let's a user connect and adds its IP to the traffic-table
  def user_connect(name, ip)
    return unless @operator

    # Free users have different auto-disconnect time than non-free users
    Captive.user_connect name, ip, (self.free(name) ? 'yes' : 'no')
  end

  # Disconnects the user and removes it's IP from the traffic-table
  def user_disconnect(name)
    return unless @operator

    Captive.user_disconnect_name name
  end

  # Unused function. See #fetch_users
  def update_connection(ip, name)
    return "From #{ip} user #{name}"
  end

  # Unused function. It's goal was to be able to split the internet-handling
  # over two devices: a gateway which will listen for 'fetch_users', and a
  # server that will communicate with the gateway
  def fetch_users
    return unless @operator

    if (server = ConfigBase.internet_cash)
      begin
        ret = Net::HTTP.get(server, '/internetCash/fetch_users')
        users = JSON.parse(ret.body)

        Persons.search_all.each { |p|
          p.groups = []
        }

        users.each { |user, pass, cash, free|
          dputs(2) { "Updating #{user}-#{pass}-#{cash}-#{free}" }
          if (u = Persons.find_by_login_name(user))
            u.password = pass
            u.internet_credit += cash
            u.groups = [:freesurf] if free
          else
            u = Persons.create(:login_name => user, :password => pass,
                               :internet_credit => cash,
                               :groups => (free ? [:freesurf] : []))
          end
        }
      rescue
        dputs(0) { "Error: Couldn't contact server" }
      end
    else
      dputs(0) { 'Error: no server defined - please add :LibNet:internetCash to config.yaml' }
    end
  end
end
