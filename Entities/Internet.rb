=begin
Internet - an interface for the internet-part of Markas-al-Nour.
=end

module Internet
  attr_accessor :operator, :device
  extend self
  include Network

  @operator = nil

  def setup
    if ConfigBase.captive_dev != 'false' && ConfigBase.has_function?(:internet_captive)
      @device = nil
      Device.add_observer(self)

      dev = Device.search_dev({uevent: {interface: ConfigBase.captive_dev}})
      if dev.length == 0
        log_msg :Internet, "Couldn't find #{ConfigBase.captive_dev}"
        Device.list
        return
      end
      update('add', dev.first)
    end
  end

  def update(operation, dev)
    return unless dev
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
          Captive.setup(@device)
          log_msg :Internet, "Got new device #{@device.inspect} - #{ConfigBase.captive_dev}"
        else
          log_msg :Internet, "New device #{dev} that doesn't match #{ConfigBase.captive_dev}"
        end
      when /operator/
        @operator = @device.operator
        log_msg :Internet, "Got new operator #{@operator}"
    end
  end

  def fetch_users
    return until @operator

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

  def take_money
    return until @operator

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
            Captive.user_disconnect_name user.login_name
          elsif self.free(user)
            dputs(2) { "User #{u} goes free" }
          elsif @device.connection_status == Device::CONNECTED
            dputs(3) { "User #{u} will pay #{cost}" }
            if user.internet_credit.to_i >= cost
              dputs(3) { "Taking #{cost} internet_credits from #{u} who has #{user.internet_credit}" }
              user.internet_credit = user.internet_credit.to_i - cost
            else
              log_msg 'take_money', "User #{u} has not enough money left - kicking"
              Captive.user_disconnect_name user.login_name
            end
          end
        else
          dputs(0) { "Error: Captive said #{u} is connected, but couldn't find that user!" +
              " Users connected: #{Captive.users_connected.inspect}" }
        end
      end
    }
  end

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

  def free(user)
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
    if user
      dputs(3) { "Searching groups for user #{user.login_name}: #{user.groups.inspect}" }
      if user.groups and user.groups.index('freesurf')
        dputs(3) { "User #{user.login_name} is on freesurf" }
        return true
      end
      if Permission.can_view(user.permissions, 'FlagInternetFree')
        dputs(3) { "User #{user.login_name} has FlagInternetFree" }
        return true
      end

      if self.active_course_for(user)
        return true
      end
    end
    dputs(3) { 'Found nothing' }
    return false
  end

  def user_connect(name, ip)
    return until @operator

    Captive.user_connect name, ip, (self.free(name) ? 'yes' : 'no')
  end

  def update_connection(ip, name)
    return "From #{ip} user #{name}"
  end

end
