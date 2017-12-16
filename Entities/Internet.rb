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
  def in_limits?(login, today = Date.today)
    return true if type == ['unlimited']
    return true unless t = Network::Captive.traffic
    t.get_day(login, 1, today.to_time).flatten[0..1].inject(:+) < limit.to_i * 1_000_000
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
        (start.to_s != '' && (Date.from_web(start) + duration.to_i > today))
  end

  # checks whether a person is active and in limits
  def in_limits?(today = Date.today)
    is_active?(today) && iclass.in_limits?(person.login_name, today)
  end
end

module Internet
  attr_accessor :device
  extend self
  include Network
  include HelperClasses

  @operator_local = nil

  # Gets all devices and adds an observer for new devices. Also sets up
  # traffic-tables for users, loading if some already exist
  def setup
    #dputs_func
    @traffic_save = Statics.get(:GestionTraffic)
    dputs(4) { "@traffic is #{@traffic_save.data_str}" }
    if ConfigBase.has_function?(:internet_captive)
      @device = nil
      connection_cmds_up = ConfigBase.connection_cmds_up
      connection_services_up = ConfigBase.connection_services_up
      connection_cmds_down = ConfigBase.connection_cmds_down
      connection_services_down = ConfigBase.connection_services_down
      connection_vpns = ConfigBase.connection_vpns

      Device.add_observer(self)
      dev, op = if (dev_id = ConfigBase.captive_dev.to_s).length > 0
                  dev_id.sub!(/:.*$/, '')
                  dputs(2) { "Searching for #{dev_id} in #{Network::Device.list}" }
                  log_msg :Internet, "Found captive dev, putting connection up: #{connection_cmds_up.inspect} " +
                                       "services: #{connection_services_up}, vpn: #{connection_vpns}"
                  Platform.connection_run_cmds(connection_cmds_up)
                  Platform.connection_services(connection_services_up, :start)
                  Platform.connection_vpn(connection_vpns, :start)
                  [Network::Device.search_dev({uevent: {interface: dev_id}}).first,
                   'add_captive']
                else
                  log_msg :Internet, "Waiting for serial interface - launching connection down commands: #{connection_cmds_down.inspect} " +
                                       "services: #{connection_services_down}, vpn: #{connection_vpns}"
                  Platform.connection_run_cmds(connection_cmds_down)
                  Platform.connection_services(connection_services_down, :stop)
                  Platform.connection_vpn(connection_vpns, :stop)
                  [Network::Device.search_dev({uevent: {driver: 'option'}}).first, 'add']
                end
      dev and update(op, dev)
    end
  end

  # Whenever a new device or a new operator is detected, this function
  # updates the internal variables.
  def update(operation, dev = nil)
    dputs(3) { "Updating operation #{operation} with dev #{dev.inspect}" }
    case operation
      when /del/
        if @device == dev
          log_msg :Internet, "Lost device #{@device}"
          @device.delete_observer(self)
          @device = nil
          Captive.accept_all
        end
      when /add/
        if dev && dev.dev._uevent && dev.dev._uevent._driver == 'option' ||
            operation == 'add_captive'
          @device = dev
          @device.add_observer(self)
          @operator_local = @device.operator
          @operator_local and Captive.setup(@device, @traffic_save.data_str)
          log_msg :Internet, "Got new device #{@device} with operator #{@operator_local}"
        else
          log_msg :Internet, "New device #{dev} that doesn't match option"
        end
      when /operator/
        @operator_local = @device.operator
        Captive.setup(@device, @traffic_save.data_str)
        log_msg :Internet, "Got new operator #{@operator_local}"
    end
  end

  # Scans all connected users and deduces money from all connected, non-free
  # users. If there is not enough money left, it kicks the user.
  def take_money
    #dputs_func
    return unless @operator_local

    Captive.cleanup
    Captive.users_connected.each { |u|
      HelperClasses::System.rescue_all do
        dputs(3) { "User is #{u}" }
        cost = @operator_local.user_cost_now.to_i

        dputs(3) { "ISP is #{@operator_local.name} and conn_type is "+
            "#{@operator_local.connection_type}" }
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

  def connection_status
    return [0, 'No device'] unless @device
    if ConfigBase.connection_status_log && ConfigBase.connection_status_log.length > 0
      reply = System.run_str("cat #{ConfigBase.connection_status_log}")
      if reply.length > 0
        return reply.split(' ')
      else
        return [2, "Error: #{reply}"]
      end
    else
      if @device.connection_status == Device::CONNECTED
        return [4, 'Up']
      else
        return [1, 'Not connected']
      end
    end
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
    # dputs_func
    case ConfigBase.allow_free[0]
      when /all/
        dputs(3) { "User #{user} is free because ALL are free" }
        return true
      when /false/
        dputs(3) { "User #{user} is NOT free because NONE are free" }
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
        dputs(3) { "User #{login} is free for a course" }
        return true
      end

      if (ip = InternetPersons.match_by_person(user)) && ip.iclass
        dputs(3) { "User #{login} has internetpersons #{ip.in_limits?}" }
        return ip.in_limits?
      end

      Activities.search_by_tags('internet').each { |act|
        dputs(3) { "Searching activity #{act}" }
        if act.start_end(user) != [nil, nil]
          if (il = act.internet_limit) == nil
            dputs(3) { "User #{user.login_name} goes free" }
            return true
          else
            dputs(3) { "found limit #{il} for user #{user.login_name}" }
            return il.in_limits?(user.login_name)
          end
        end
      }

      if ic = ConfigBase.iclass_default
        dputs(3) { "User #{login} falls into default : #{ic.in_limits?(login)}" }
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

  def operator
    # Wow - this is really ugly. Why do two different listeners (Internet and MobileControl)
    # don't agree on who is the operator?
    return @operator_local unless $MobileControl
    $MobileControl.operator
  end

  # Lets a user connect and adds its IP to the traffic-table
  def user_connect(name, ip)
    return unless @operator_local
    if @device.connection_status != Device::CONNECTED
      $MobileControl and $MobileControl.connect(true)
    end

    # Free users have different auto-disconnect time than non-free users
    Captive.user_connect name, ip, (self.free(name) ? 'yes' : 'no')
  end

  # Disconnects the user and removes its IP from the traffic-table
  def user_disconnect(name)
    return unless @operator_local

    Captive.user_disconnect_name name
  end
end
