# Holds the data available for a person. The permission is a regexp
# giving access to different views and it's blocks
#
# Configuration:
# adduser_cmd - is called after ldapadduser returns with the username as argument

class String
  def capitalize_all
    self.split(" ").collect { |s| s.capitalize }.join(" ")
  end

  def capitalize_all!
    self.replace self.capitalize_all
  end
end

class IsNecessary < Exception
  attr :for_course

  def initialize(course)
    @for_course = course
  end
end


class Persons < Entities
  attr :print_card, :admin_users
  attr_reader :resps
  self.needs :Courses

  def setup_data
    add_new_storage :LDAP

    value_block :address
    value_str_LDAP :first_name, :ldap_name => "sn"
    value_str_LDAP :family_name, :ldap_name => "givenname"
    value_date :birthday
    value_str :address
    value_str_LDAP :phone, :ldap_name => "mobile"
    value_str_LDAP :email, :ldap_name => "mail"
    value_str_LDAP :town, :ldap_name => "l"
    value_str_LDAP :country, :ldap_name => "st"
    value_list_drop :gender, "%w( male female n/a )"

    value_block :admin
    value_str :account_name_due
    value_str :account_name_cash
    value_str :role_diploma
    value_list :permissions, "Permission.list.sort"

    value_block :internet
    value_list :groups, "%w( freesurf sudo print localonly share ).sort"
    value_list_single :internet_none, "[]"

    value_block :read_only
    value_str_ro_LDAP :login_name, :ldap_name => "uid"
    # credit -> internet_credit
    # credit_due -> account_total_due
    value_int_ro :internet_credit
    value_int_ro :account_total_due

    value_block :hidden
    value_str :session_id
    value_str_LDAP :password, :ldap_name => "userPassword"
    value_str :password_plain
    value_int_LDAP :person_id, :ldap_name => "uidnumber"

    ddir = Courses.dir_diplomas
    cdir = "#{ddir}/cartes"
    if !File.exist? cdir
      FileUtils::mkdir(cdir)
    end
    
    defined? @admin_users or @admin_users = true
    @student_card ||= "student_card.odg"
    @print_card = OpenPrint.new(
      "#{ddir}/#{@student_card}", cdir)
    @resps = []
  end

  # Searches for an empty name starting with "login", adding 2, 3, 4, ...
  def find_empty_login_name(login)
    suffix = ""
    login = accents_replace(login)
    while match_by_login_name(login + suffix.to_s)
      dputs(2) { "Found #{login + suffix.to_s} to already exist" }
      suffix = suffix.to_i + 1
      suffix = 2 if suffix == 1
    end
    login + suffix.to_s
  end

  def create_first_family(fullname)
    # Trying to be intelligent about splitting up of names
    if fullname.split(" ").length > 1
      names = fullname.split(' ')
      s = names.length < 4 ? 0 : 1
      first = names[0..s].join(" ")
      family = names[(s+1)..-1].join(" ")
      dputs(2) { "Creating user #{names.inspect} as #{first} - #{family}" }
      [first, family]
    else
      [fullname, ""]
    end
  end

  def accents_replace(login)
    login = login.downcase.gsub(/ /, "_")
    accents = Hash[*%w( a àáâä e éèêë i ìíîï o òóôöœ u ùúûü c ç ss ß )]
    dputs(2) { "Login was #{login}" }
    accents.each { |k, v|
      login.gsub!(/[#{v}]/, k)
    }
    login.gsub!(/[^a-z0-9_-]/, '_')
    dputs(2) { "Login is #{login}" }
    login
  end

  # Creates a login-name out of "first" and "family" name - should work nicely in
  # Africa, perhaps a bit bizarre in Western-countries (like "tlinus" instead of
  # "ltorvalds")
  # if "family" is empty, it tries to generate some sensible values for "first" and
  # "family" by itself
  def create_login_name(first, family = "")
    if family.length == 0
      first, family = create_first_family(first)
    end
    if family.length > 0
      dputs(2) { "Family name + First name" }
      login = family.chars.first + first.split.first
    else
      login = first.split.first
    end

    accents_replace(login)
  end

  def create(d)
    # Sanitize first and family-name
    if d.has_key? :complete_name
      d[:first_name] = d[:complete_name]
    end
    if d.has_key? :first_name
      if not d.has_key? :family_name or d[:family_name].length == 0
        d[:first_name], d[:family_name] = create_first_family(d[:first_name])
      end
      d[:first_name].capitalize_all!
      d[:family_name].capitalize_all!
    elsif d.has_key? :login_name
      d[:first_name] = d[:login_name]
    else
      dputs(0){"Error: Trying to create Person with missing names: #{d.inspect}"}
      return nil
    end
    if !d[:login_name] or d[:login_name].length == 0
      d[:login_name] = create_login_name(d[:first_name], d[:family_name])
    end

    if d.has_key? :login_name_prefix
      d[:login_name] = d[:login_name_prefix] + d[:login_name]
    end
    d[:login_name] = find_empty_login_name(d[:login_name])
    d[:person_id] = nil
    log_msg :person, "Creating Person #{d.inspect}"

    person = super(d, true)

    person.password_plain = d.has_key?(:password) ? d[:password] : rand(10000).to_s.rjust(4, "0")
    person.password = person.password_plain

    if defined? @cmd_after_new
      dputs(2) { "Going to call #{@cmd_after_new}" }
      %x[ #{@cmd_after_new} #{person.login_name} #{person.password_plain} ]
    end

    return person
  end

  def self.create_empty
    Entities.Persons.create([])
  end

  def update(session)
    super(session).merge({:account_total_due => session.owner.internet_credit})
  end

  # Adds cash to a persons account. The hash "data" should contain the following
  # fields:
  # - credit_add : how much CFA to add
  # - person_id : the id of the person to receive the credit
  def add_internet_credit(session, data)
    dputs(5) { "data is #{data.inspect}" }
    client = match_by_login_name(data['login_name'].to_s)
    if data['credit_add'] and client
      actor = session.owner
      dputs(3) { "Adding cash to #{client.full_name} from #{actor.full_name}" }
      if client
        actor.add_internet_credit(client, data['credit_add'])
      end
      return client
    end
    return nil
  end

  def get_login_with_permission(perm)
    persons = Entities.Persons.search_by_permissions(perm)
    if persons
      # The "select" at the end removes empty entries
      persons.collect { |p|
        p.login_name
      }.select { |s| s }
    else
      []
    end
  end

  def list_teachers
    get_login_with_permission("teacher").sort
  end

  def list_assistants
    get_login_with_permission("assistant").sort
  end

  def list_students
    get_login_with_permission("student").sort
  end

  def listp_account_due
    search_all.select { |p|
      p.account_due and p.login_name != "admin"
    }.collect { |p|
      dputs(4) { "p is #{p.full_name}" }
      dputs(4) { "account is #{p.account_due.get_path}" }
      amount = (p.account_due.total.to_f * 1000).to_i
      name = p.full_name
      if name.length == 0
        name = p.login_name
      end
      [p.person_id, "#{amount.to_s.rjust(6)} - #{name}"]
    }.sort { |a, b|
      a[1] <=> b[1]
    }.reverse
  end

  def save_data(d)
    d = d.to_sym
    dputs(3) { "d is #{d.inspect}" }

    if !d[:first_name] and !d[:person_id]
      return {:first_name => "user"}
    end

    [:first_name, :family_name].each { |n|
      d[n] && d[n].capitalize_all!
    }

    super(d)
  end

  def data_create(data)
    dputs(2) { "Creating new data #{data.inspect}" }
    if has_storage? :LDAP
      user = data[:login_name]
      if Kernel.system("ldapadduser #{user} plugdev")
        if defined? @adduser_cmd
          dputs(2) { "Going to call #{@adduser_cmd} #{user.inspect}" }
          %x[ #{@adduser_cmd} #{user} ]
        end
      else
        dputs(0) { "Error: Couldn't create #{user}" }
      end
    end
  end

  def find_full_name(name)
    dputs(2) { "Searching for #{name}" }
    @data.each_key { |k|
      if @data[k]
        fn = "#{data[k][:first_name]} #{data[k][:family_name]}"
        dputs(2) { "Searching in #{fn}" }
        if fn =~ /#{name}/i
          dputs(2) { "Found it" }
          return get_data_instance(k)
        end
      end
    }
    return nil
  end

  def find_name_or_create(name)
    first, last = name.split(" ", 2)
    find_full_name(name) or
      create(:first_name => first, :family_name => last)
  end

  def login_to_full(login)
    p = match_by_login_name(login)
    p ? p.full_name : ""
  end

  def listp_responsible(session = nil)
    list = search_by_permissions("teacher")
    if session
      list = list.select { |p|
        p.login_name =~ /^#{session.owner.login_name}_/
      }.push(session.owner)
    end
    list.collect { |p|
      [p.person_id, p.full_name]
    }
  end

  def migration_1(p)
    if p.person_id == 0
      dputs(0) { "Error: Oups, found person with id 0 - trying to change this" }
      p.person_id = Persons.new_id[:person_id]
      dputs(2) { "Putting person-id to #{p.person_id}" }
    end
  end

  def migration_2_raw(p)
    dputs(2) { "p is #{p.class}" }
    p._internet_credit = p._credit
    p._account_total_due = p._credit_due
    p._account_name_due = p._account_due
  end

  def migration_3(p)
    if p.permissions.class != Array
      p.permissions = []
    end
  end

  def migration_4(p)
    p.gender = %w( n/a )
  end
  
  def responsibles( force_update = false )
    if force_update or @resps.size == 0
      dputs(3){"Making responsible-cache"}
      @resps = Persons.search_all.select{|p| 
        dputs(4){"Person #{p.login_name} has #{p.permissions.inspect}"}
        p.permissions and Permission.can_view( p.permissions.reject{|perm| 
            perm.to_s == "admin"}, "FlagResponsible" )
      }
      @resps = @resps.collect{|p|
        [p.person_id, p.full_name]
      }.sort{|a,b| a.last <=> b.last}
    else
      dputs(3){"Lazily using responsible-cache"}
    end
    @resps
  end

  def create_add_course( student, owner, course, check_double = false )
    prefix = ConfigBase.has_function?( :course_server ) ?
      "#{owner.login_name}_" : ""
    login_name = Persons.create_login_name( student )
    if not ( person = Persons.match_by_login_name( prefix + student ) )
      if check_double and
          Persons.search_by_login_name( "^#{prefix}#{login_name}[0-9]*$").length > 0
        return nil
      else
        person = Persons.create( {:first_name => name,
            :login_name_prefix => prefix,
            :permissions => %w( student ), :town => @town, :country => @country })
      end
    end
    #person.email = "#{person.login_name}@ndjair.net"
    person and course.students.push( person.login_name )
    person
  end
  
  def delete_all( local_only = false )
    super( local_only )
    @resps = []
  end
end


#
### One person only
#

class Person < Entity
  attr_accessor :account_due, :account_due_paid, 
    :account_cash, :account_service

  def setup_instance
    dputs(3) { "Data is #{@proxy.data[@id].inspect}" }

    self.internet_credit = internet_credit.to_i
    #data_set( :internet_credit, data_get( :internet_credit ).to_i )
    @account_service = @account_due = @account_cash = nil

    update_account_due
    update_account_cash
  end

  # This is only for testing - don't use in real life!
  def disable_africompta
    internet_credit = internet_credit
    internet_credit = 0 if not internet_credit
    self.account_total_due = internet_credit
    @account_due = nil
  end

  def update_account_due
    if can_view :FlagAddInternet and login_name != "admin"
      if login_name.to_s == ""
        dputs(0){"Error: Login-name is empty! Not good! #{self.inspect}"}
        return
      end
      dputs(3){"Adding account_due to -#{login_name.inspect}-"}
      #acc = data_get( :account_name_due )
      acc = account_name_due
      if acc.to_s.length == 0
        acc = (full_name || login_name).capitalize
        #data_set( :account_name_due, acc )
        self.account_name_due = acc
      end
      lending = "#{get_config('Root::Lending', :Accounting, :lending)}::#{acc}"
      service = get_config("Root::Income::Services", :Accounting, :service)
      dputs(2) { "Searching accounts for #{full_name} with "+
          "lending: #{lending} - service: #{service}" }
      @account_due = Accounts.get_by_path_or_create(lending,
        acc, false, -1, true)
      @account_due_paid = Accounts.get_by_path_or_create("#{lending}::Paid",
        acc, false, -1, true)
      @account_service = Accounts.get_by_path_or_create(service,
        acc, false, 1, false)
    end
  end

  def update_account_cash
    if can_view :FlagAccounting and login_name != "admin"
      #acc = data_get( :account_name_cash )
      acc = account_name_cash
      if acc.to_s.length == 0
        acc = (first_name || login_name).capitalize
        #data_set( :account_name_cash, acc )
        self.account_name_cash = acc
      end
      dputs(3) { "Getting cash account #{acc}" }
      cc = "#{get_config('Root::Cash', :Accounting, :cash)}::#{acc}"
      @account_cash = Accounts.get_by_path_or_create(cc, cc, false, -1, true)
      dputs(3) { "Account is #{@account_cash.inspect}" }
    end
  end

  def total_cash
    if @account_cash
      (@account_cash.total.to_f * 1000).to_i
    else
      0
    end
  end

  def data_set_old(field, value, msg = nil, undo = true, logging = true)
    old_value = data_get(field)
    if old_value != value
      dputs(4) { "Saving #{field} = #{value}" }
      if logging
        if undo
          @proxy.log_action(@id, {field => value}, msg, :undo_set_entry, old_value)
        else
          @proxy.log_action(@id, {field => value}, msg)
        end
      end
    end
    ret = super(field, value)
    case field.to_s
    when /account_name_due/
      update_account_due
    when /account_name_cash/
      update_account_cash
    when /permissions/
      # They will check for themself
      update_account_cash
      update_account_due
    when /groups/
      update_smb_passwd
    end
    return ret
  end

  def groups=(g)
    self._groups = g
    update_smb_passwd
  end

  def update_accounts
    update_account_cash
    update_account_due
  end

  def permissions=(p)
    has_teacher = self._permissions and self._permissions.concat(p).index( "teacher" )
    dputs(3){"has_teacher is #{has_teacher} - permissions are #{p}"}
    self._permissions = p
    if has_teacher
      Persons.responsibles( true )
    end
    update_accounts
  end

  def account_name_due=(a)
    self._account_name_due = a
    update_account_due
  end

  def account_name_cash=(a)
    self._account_name_cash = a
    update_account_cash
  end

  def update_smb_passwd(pass = password)
    if ConfigBase.has_function?(:share) and (groups and groups.index("share"))
      if not @proxy.has_storage? :LDAP
        if Persons.admin_users
          %x[ if which adduser; then adduser --disabled-password --gecos "#{self.full_name}" #{self.login_name};
            else useradd #{self.login_name}; fi ]
        end
      end
      log_msg :person, "Changing password in Samba to #{pass}"
      dputs(3) { "( echo #{pass}; echo #{pass} ) | smbpasswd -s -a #{self.login_name}" }
      %x[ ( echo #{pass}; echo #{pass} ) | smbpasswd -s -a #{self.login_name} ]
    end
  end

  #def data_set_log(field, value, msg = nil, undo = true, logging = true )
  #  data_set( field, value, msg, undo, logging )
  #end

  def account_total_due
    if @account_due
      dputs(2) { "internet_credit is #{@account_due.total.inspect}" }
      (@account_due.total.to_f * 1000.0 + 0.5).to_i
    else
      #data_get( :account_total_due, false, true )
      _account_total_due
    end
  end

  def add_internet_credit(client, internet_credit)
    dputs(3) { "Adding #{internet_credit}CFA to #{client.internet_credit} for #{client.login_name}" }
    internet_credit_before = client.internet_credit
    if internet_credit.to_i < 0 and internet_credit.to_i.abs > client.internet_credit.to_i
      internet_credit = -client.internet_credit.to_i
    end
    client.data_set_log(:_internet_credit, (client.internet_credit.to_i + internet_credit.to_i).to_s,
      "#{self.person_id}:#{internet_credit}")
    pay_service(internet_credit, "internet_credit pour -#{client.login_name}:#{internet_credit}-")
    log_msg("AddCash", "#{self.login_name} added #{internet_credit} for #{client.login_name}: " +
        "#{internet_credit_before} + #{internet_credit} = #{client.internet_credit}")
    log_msg("AddCash", "Total due: #{account_total_due}")
  end

  def pay_service(credit, msg, date = nil)
    self.account_total_due = 0
    if @account_due
      date = date ? Date.parse( date ) : Date.today

      Movements.create("#{msg}", date.strftime("%Y-%m-%d"),
        credit.to_i / 1000.0, @account_due, @account_service)
      self.account_total_due = (@account_due.total.to_f * 1000.0 + 0.5).to_i
    else
      #account_total_due = data_get( :account_total_due ).to_i + credit.to_i
      total = self.account_total_due.to_i + credit.to_i
      data_set_log(:_account_total_due, total, msg)
    end
  end

  def check_pass(pass)
    if @proxy.has_storage? :LDAP
      # We have to try to bind to the LDAP
      dputs(2) { "Trying LDAP" }
      #return @proxy.storage[:LDAP].check_login( data_get(:login_name), pass )
      return @proxy.storage[:LDAP].check_login(login_name, pass)
    else
      #dputs( 0 ){ "is #{pass} equal to #{data_get( :password ) }" }
      dputs(2) { "is #{pass} equal to #{password}" }
      #return pass == data_get( :password )
      return pass == password
    end
  end

  def services_active
    dputs(4) { "Entering" }
    payments = Entities.Payments.search_by_client(self.id)
    if payments
      payments.select { |p|
        dputs(3) { "Found payment for #{self.full_name}: #{p.inspect}" }
        if p.desc =~ /^Service:/
          service = Entities.Services.match_by_name(p.desc.gsub(/^Service:/, ''))
          dputs(3) { "Found service #{service}" }
          service.duration == 0 or p.date + service.duration * 60 * 60 * 24 >= Time.now.to_i
        else
          false
        end
      }.collect { |p|
        p.desc.gsub(/^Service:/, '')
      }
    else
      []
    end
  end

  def password=(pass)
    p = pass
    if @proxy.has_storage? :LDAP
      dputs(2) { "Changing password for #{self.login_name}: #{pass}" }
      p = %x[ slappasswd -s #{pass} ]
      dputs(2) { "Hashed password for #{self.login_name} is: #{pass}" }
    end
    update_smb_passwd(pass)
    log_msg :person, "Setting password (#{pass}) for #{self.login_name} to #{p}"
    self._password = p
    if (permissions and permissions.index("center")) or
        (groups and groups.index("share")) or
        (not self.password_plain or self.password_plain == "" or
          self.password_plain == pass)
      self.password_plain = pass
    else
      dputs(2) { self.password_plain.inspect }
      self.password_plain = "****"
    end
  end

  def full_name
    ret = []
    first_name and ret.push first_name
    family_name and ret.push family_name
    ret.length == 0 and ret.push login_name
    ret.join(" ")
  end

  def replace(orig, field, str)
    fields.each { |f|
      orig.gsub!(f[0], f[1].to_s)
    }
    orig
  end

  def lp_cmd=(v)
    @proxy.print_card.lp_cmd = v
  end

  def print(counter = nil)
    ctype = "Visiteur"
    courses = Courses.list_courses_for_person(self)
    if courses and courses.length > 0
      dputs(3) { "Courses is #{courses.inspect}" }
      ctype = Courses.match_by_course_id(courses[0][0]).description
    end
    fname = "#{person_id.to_s.rjust(6, '0')}-#{full_name.gsub(/ /, '_')}"
    courses = ["", ""]
    Courses.list_courses_for_person(self).each { |c|
      courses.unshift(Courses.match_by_course_id(c.first).ctype.description)
    }
    replace = [[/--NAME1--/, first_name],
      [/--NAME2--/, family_name],
      [/--BDAY--/, birthday],
      [/--TDAY--/, `LC_ALL=fr_FR.UTF-8 date +"%d %B %Y"`],
      [/--TOWN--/, town],
      [/--TEL--/, phone],
      [/--UNAME--/, login_name],
      [/--EMAIL--/, email],
      [/--CTYPE--/, ctype],
      [/--COURSE1--/, courses[0]],
      [/--COURSE2--/, courses[1]],
      [/--PASS--/, password_plain]]
    if center = Persons.find_by_permissions( :center )
      url, email = center.email.to_s.split( "::" )
      replace.concat( [[/--CENTER_NAME--/, center.full_name],
          [/--CENTER_ADDRESS--/, center.address],
          [/--CENTER_TOWN--/, center.town],
          [/--CENTER_COUNTRY--/, center.country],
          [/--CENTER_TEL--/, center.phone],
          [/--CENTER_URL--/, url],
          [/--CENTER_EMAIL--/, email]])
    end
    dputs(3){"Replace is #{replace.inspect}"}
    @proxy.print_card.print( replace, nil, fname )
  end

  def to_list
    [login_name, "#{full_name} - #{login_name}:#{password_plain}"]
  end

  def session
    Sessions.match_by_sid(self.session_id)
  end

  def first_name=(v)
    self._first_name = v.to_s.capitalize_all
  end

  def family_name=(v)
    self._family_name = v.to_s.capitalize_all
  end

  def get_cash(person, amount)
    dputs(3) { "Amount is #{amount.inspect} and #{person.inspect} will receive it" }
    amount = amount.to_i
    if amount < 0
      dputs(0) { "Error: Can't transfer a negative amount here" }
      return false
    end
    if not person.account_due
      dputs(0) { "Error: #{person.login_name}::#{person.full_name} has no account_due" }
      return false
    end
    if not @account_cash
      dputs(0) { "Error: #{self.inspect} has no account_cash" }
      return false
    end
    dputs(3) { "Transferring #{amount} from #{@account_cash.get_path} to " +
        "#{person.account_due.get_path}"
    }
    Movements.create("Transfert au comptable", Date.today,
      amount / 1000.0, @account_cash, person.account_due)
    return true
  end
  
  def get_all_due( person )
    if person.account_due && @account_cash
      value = 0
      person.account_due.movements.each{|m|
        dputs(3){"Moving #{m.inspect}"}
        value += m.get_value( person.account_due )
        m.move_from_to( person.account_due, person.account_due_paid )
      }
      dputs(3){"Value is #{value}"}
      Movements.create("Transfert au comptable", Date.today,
        value, @account_cash, person.account_due_paid )
    end
  end

  def can_view(v)
    #Permission.can_view( data_get(:permissions), v )
    Permission.can_view(permissions, v)
  end

  def has_all_rights_of(person)
    dputs(4) { "#{person.permissions} - #{permissions}" }
    pv1 = Permission.views(permissions)
    Permission.views(person.permissions).each { |p|
      found = false
      pv1.each { |p1|
        if p =~ /^#{p1}$/
          found = true
          dputs(4) { "Found my #{p1} matches his #{p}" }
        end
      }
      not found and return false
    }
    return true
  end

  def delete
    Courses.search_all.each { |course|
      dputs(3) { "Checking course #{course.name}" }
      [:teacher, :assistant, :responsible, :center].each { |role|
        begin
          r = course.data_get("_#{role}")
        rescue Exception => e
          if e.message == "WrongIndex"
            dputs(0) { "Error: Role :#{role} is not well defined - resetting to nil" }
            course.data_set("_#{role}", nil)
          end
        end
        dputs(3) { "Role #{role} is #{r.inspect}" }
        if r and r.login_name == login_name
          raise IsNecessary.new(course)
        end
      }
    }

    Courses.data.values.each { |d|
      if d[:students] and d[:students].index(login_name)
        d[:students] -= [login_name]
      end
    }
    Shares.search_all.each { |s|
      s.acl.delete login_name
    }
    AccessGroups.search_all.each { |ag|
      ag.members and ag.members.delete login_name
    }
    Grades.search_by_student(self).each { |g|
      g.delete
    }

    if @proxy.has_storage? :LDAP
      if !Kernel.system("ldapdeleteuser #{self.login_name}")
        dputs(0) { "Error: couldn't delete user #{self.inspect}" }
      end
    elsif Persons.admin_users
      %x[ if which deluser; then deluser #{self.login_name}; else
          userdel #{self.login_name}; fi ]
    end
    if ConfigBase.has_function?(:share)
      %x[ smbpasswd -x #{self.login_name} ]
    end
    super
  end

  def get_unique
    login_name
  end

  def has_permission?(perm)
    dputs(4) { "Checking #{perm.inspect} in #{permissions.inspect}" }
    dputs(4) { "Which is #{Permission.views(permissions).inspect }" }
    return true if permissions.index(perm.to_s)
    Permission.views(permissions).select { |p|
      dputs(4) { "Checking permission #{p.inspect} of #{perm.inspect}" }
      dputs(4) { "Result is #{perm.to_s =~ /^#{p.to_s}$/}" }
      perm.to_s =~ /^#{p.to_s}$/
    }.length > 0
  end

  def courses
    Courses.search_all.select { |c|
      c[:students] and c[:students].index( login_name )
    }
  end
  
  def report_list_movements( from = nil, to = from, account = account_due )
    if from
      account.movements.select{|m|
        dputs(3){"Date is #{m.date.inspect}"}
        (from..to).include? m.date
      }
    else
      account.movements
    end.collect{|m|
      [ m.global_id, 
        [ m.date, 
          "#{m.get_other_account(account).name}: #{m.desc}", 
          m.value_form ] 
      ]
    }
  end
  
  def report_list( report, date = nil )
    date ||= Date.today
    case report
    when :daily, 1
      report_list_movements( date )
    when :weekly, 2
      week = Date.commercial( date.year, date.cweek, 1 )
      report_list_movements( week, week + 6 )
    when :monthly, 3
      report_list_movements(
        Date.new( date.year, date.month, 1 ),
        Date.new( date.year, date.month, - 1 ) )
    when :all, 4
      report_list_movements
    when :all_paid, 5
      report_list_movements( nil, nil, account_due_paid )
    end
  end
  
  def report_pdf( report, date = nil )
    file = "/tmp/cash_#{login_name}.pdf"
    Prawn::Document.generate( file,
      :page_size   => "A4",
      :page_layout => :portrait,
      :bottom_margin => 2.cm ) do |pdf|

      sum = 0
      movs = report_list( report, date ).reverse
      pdf.text "Report for #{full_name}", :align => :center, :size => 20
      pdf.font_size 10
      pdf.text "From #{movs.first[1][0]} to #{movs.last[1][0]}"
      pdf.text "Account: #{account_due.path}"
      pdf.move_down 1.cm
      
      if movs.length > 0
        header = [ ["Date", "Description", "Value", "Sum"].collect{|ch|
            {:content => ch, :align => :center}}]
        dputs(3){"Movs is #{movs.inspect}"}
        pdf.table( header + movs.collect{|m_id, m|
            [ {:content => "#{m[0]}", :align => :center },
              m[1],
              {:content => "#{m[2]}", :align => :right}, 
              {:content => "#{Account.total_form( 
                sum += m[2].gsub(',','').to_f / 1000 )}", 
                :align => :right} ]
          }, :header => true, :column_widths => [70,300,75,75] )
        pdf.move_down( 2.cm )
      end

      pdf.repeat(:all, :dynamic => true) do
        pdf.draw_text "#{Date.today} - #{account_due.path}",
          :at => [0, -20], :size => 10
        pdf.draw_text pdf.page_number, :at => [19.cm, -20]
      end
    end
    file
    
  end
end
