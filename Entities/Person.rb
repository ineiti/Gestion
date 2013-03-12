# Holds the data available for a person. The permission is a regexp
# giving access to different views and it's blocks
#
# Configuration:
# adduser_cmd - is called after ldapadduser returns with the username as argument

class String
  def capitalize_all
    self.split(" ").collect{|s| s.capitalize}.join(" ")
  end

  def capitalize_all!
    self.replace self.capitalize_all
  end
end



class Persons < Entities
  attr :print_card
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

    value_block :admin
    value_str :account_name_due
    value_str :account_name_cash
    value_str :role_diploma
    value_list :permissions, "Permission.list"

    value_block :internet
    value_list :groups, "%w( freesurf sudo print localonly )"
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

    if ddir = get_config( nil, :DiplomaDir )
      cdir = "#{ddir}/cartes"
      if ! File.exist? cdir
        FileUtils::mkdir( cdir )
      end
      @print_card = OpenPrint.new( 
        "#{ddir}/carte_etudiant.odg", "#{ddir}/cartes" )
    end

    LOAD_DATA
  end

  # Searches for an empty name starting with "login", adding 2, 3, 4, ...
  def find_empty_login_name( login )
    suffix = ""
    login = accents_replace( login )
    while find_by_login_name( login + suffix.to_s )
      dputs( 2 ){ "Found #{login + suffix.to_s} to already exist" }
      suffix = suffix.to_i + 1
      suffix = 2 if suffix == 1
    end
    login + suffix.to_s
  end

  def create_first_family( fullname )
    # Trying to be intelligent about splitting up of names
    if fullname.split(" ").length > 1
      names = fullname.split(' ')
      s = names.length < 4 ? 0 : 1
      first = names[0..s].join(" ")
      family = names[(s+1)..-1].join(" ")
      dputs( 1 ){ "Creating user #{names.inspect} as #{first} - #{family}" }
      [ first, family ]
    else
      [ fullname, "" ]
    end
  end

  def accents_replace( login )
    login = login.downcase.gsub( / /, "_" )
    accents = Hash[ *%w( a àáâä e éèêë i ìíîï o òóôöœ u ùúûü c ç ss ß )]
    dputs( 2 ){ "Login was #{login}" }
    accents.each{|k,v|
      login.gsub!( /[#{v}]/, k )
    }
    login.gsub!( /[^a-z0-9_-]/, '_' )
    dputs( 2 ){ "Login is #{login}" }
    return login
  end

  # Creates a login-name out of "first" and "family" name - should work nicely in
  # Africa, perhaps a bit bizarre in Western-countries (like "tlinus" instead of
  # "ltorvalds")
  # if "family" is empty, it tries to generate some sensible values for "first" and
  # "family" by itself
  def create_login_name( first, family = "" )
    if family.length == 0
      first, family = create_first_family( first )
    end
    if family.length > 0
      dputs( 2 ){ "Family name + First name" }
      login = family.chars.first + first.split.first
    else
      login = first.split.first
    end

    accents_replace( login )
  end

  def create( d )
    # Sanitize first and family-name
    if d.has_key? :complete_name
      d[:first_name] = d[:complete_name]
    end
    if d.has_key? :first_name
      if not d.has_key? :family_name or d[:family_name].length == 0
        d[:first_name], d[:family_name] = create_first_family( d[:first_name] )
      end
      d[:first_name].capitalize_all!
      d[:family_name].capitalize_all!
    end
    if ! d[:login_name]
      d[:login_name] = create_login_name( d[:first_name], d[:family_name] )
    end

    d[:login_name] = find_empty_login_name( d[:login_name] )
    d[:person_id] = nil
    dputs( 1 ){ "Creating #{d.inspect}" }

    person = super( d )

    person.password_plain = d.has_key?( :password ) ? d[:password] : rand( 10000 ).to_s.rjust(4,"0")
    person.password = person.password_plain

    if defined? @cmd_after_new
      dputs( 2 ){ "Going to call #{@cmd_after_new}" }
      %x[ #{@cmd_after_new} #{person.login_name} #{person.password_plain} ]
    end

    return person
  end

  def self.create_empty
    Entities.Persons.create( [] )
  end

  def update( session )
    super( session ).merge( { :account_total_due => session.owner.internet_credit } )
  end

  # Adds cash to a persons account. The hash "data" should contain the following
  # fields:
  # - credit_add : how much CFA to add
  # - person_id : the id of the person to receive the credit
  def add_internet_credit( session, data )
    dputs( 5 ){ "data is #{data.inspect}" }
    client = match_by_login_name( data['login_name'].to_s )
    if data['credit_add'] and client
      actor = session.owner
      dputs( 3 ){ "Adding cash to #{client.full_name} from #{actor.full_name}" }
      if client
        actor.add_internet_credit( client, data['credit_add'])
      end
      return client
    end
    return nil
  end

  def get_login_with_permission( perm )
    persons = Entities.Persons.search_by_permissions( perm )
    if persons
      # The "select" at the end removes empty entries
      persons.collect{|p|
        p.login_name
      }.select{|s|s}
    else
      []
    end
  end

  def list_teachers
    get_login_with_permission( "teacher" ).sort
  end

  def list_assistants
    get_login_with_permission( "assistant" ).sort
  end

  def list_students
    get_login_with_permission( "student" ).sort
  end
  
  def listp_account_due
    search_all.select{|p|
      p.account_due and p.login_name != "admin"
    }.collect{|p|
      dputs( 4 ){ "p is #{p.full_name}" }
      dputs( 4 ){ "account is #{p.account_due.get_path}" }
      amount = (p.account_due.total.to_f * 1000).to_i
      name = p.full_name
      if name.length == 0
        name = p.login_name
      end
      [p.person_id, "#{amount.to_s.rjust(6)} - #{name}"]
    }.sort{|a,b|
      a[1] <=> b[1]
    }.reverse
  end

  def save_data( d )
    d = d.to_sym
    dputs( 3 ){ "d is #{d.inspect}" }

    if ! d[:first_name] and ! d[:person_id]
      return { :first_name => "user" }
    end
		
    [ :first_name, :family_name ].each{|n|
      d[n] && d[n].capitalize_all!
    }

    super( d )
  end

  def data_create( data )
    dputs( 0 ){ "Creating new data #{data.inspect}" }
    if has_storage? :LDAP
      user = data[:login_name]
      if %x[ ldapadduser #{user} plugdev ] and defined? @adduser_cmd
        dputs( 0 ){ "Going to call #{@adduser_cmd}" }
        %x[ #{@adduser_cmd} #{user} ]
      end
    end
  end

  def find_full_name( name )
    dputs( 2 ){ "Searching for #{name}" }
    @data.each_key{|k|
      if @data[k]
        fn = "#{data[k][:first_name]} #{data[k][:family_name]}"
        dputs( 2 ){ "Searching in #{fn}" }
        if fn =~ /#{name}/i
          dputs( 2 ){ "Found it" }
          return get_data_instance(k)
        end
      end
    }
    return nil
  end

  def find_name_or_create( name )
    first, last = name.split( " ", 2 )
    find_full_name( name ) or
      create( :first_name => first, :family_name => last )
  end

  def login_to_full( login )
    p = find_by_login_name( login )
    p ? p.full_name : ""
  end
  
  def migration_1( p )
    if p.person_id == 0
      dputs(0){"Oups, found person with id 0 - trying to change this"}
      p.person_id = Persons.new_id[:person_id]
      dputs(0){"Putting person-id to #{p.person_id}"}
    end
  end
  
  def migration_2( p )
    p.internet_credit = p.credit
    p.account_total_due = p.credit_due
    p.account_name_due = p.account_due
  end
end



#
### One person only
#

class Person < Entity
  attr_accessor :account_due, :account_cash
  def setup_instance
    dputs(3){"Data is #{@proxy.data[@id].inspect}"}

    data_set( :internet_credit, data_get( :internet_credit ).to_i )
    @account_service = @account_due = @account_cash = nil

    update_account_due
    update_account_cash
  end
  
  # This is only for testing - don't use in real life!
  def disable_africompta
    internet_credit = internet_credit
    internet_credit = 0 if not internet_credit
    data_set( :account_total_due, internet_credit )
    @account_due = nil
  end

  def update_account_due
    if can_view :FlagAddInternet and login_name != "admin"
      acc = data_get( :account_name_due )
      if acc.to_s.length == 0
        acc = ( first_name || login_name ).capitalize 
        data_set( :account_name_due, acc )
      end
      lending = "#{get_config( 'Root::Lending', :Accounting, :Lending )}::#{acc}"
      service = get_config( "Root::Income::Services", :Accounting, :Service )
      dputs( 2 ){ "Searching accounts for #{full_name} with "+
          "lending: #{lending} - service: #{service}" }
      @account_due = Accounts.get_by_path_or_create( lending, 
        lending, false, -1, true )
      @account_service = Accounts.get_by_path_or_create( service,
        service, false, 1, false )
    end
  end
  
  def update_account_cash
    if can_view :FlagAccounting and login_name != "admin"
      acc = data_get( :account_name_cash )
      if acc.to_s.length == 0
        acc = ( first_name || login_name ).capitalize 
        data_set( :account_name_cash, acc )
      end
      dputs(3){"Getting account #{acc}"}
      cc = get_config( "Root::Cash::#{acc}", 
        :Accounting, :Cash )
      @account_cash = ( Accounts.get_by_path( cc ) or 
          Accounts.create_path( cc, cc, false, -1, true ) )
    end
  end
  
  def total_cash
    if @account_cash
      ( @account_cash.total.to_f * 1000 ).to_i
    else
      0
    end
  end

  def data_set(field, value, msg = nil, undo = true, logging = true )
    old_value = data_get(field)
    if old_value != value
      dputs( 0 ){ "Saving #{field} = #{value}" }
      if logging
        if undo
          @proxy.log_action( @id, { field => value }, msg, :undo_set_entry, old_value )
        else
          @proxy.log_action( @id, { field => value }, msg )
        end
      end
    end
    ret = super( field, value )
    case field.to_s
    when /account_name_due/
      update_account_due
    when /account_name_cash/
      update_account_cash
    when /permissions/
      # They will check for themself
      update_account_cash
      update_account_due
    end
    return ret
  end

  def data_set_log(field, value, msg = nil, undo = true, logging = true )
    data_set( field, value, msg, undo, logging )
  end

  def account_total_due
    if @account_due
      dputs( 2 ){ "internet_credit is #{@account_due.total.inspect}" }
      ( @account_due.total.to_f * 1000.0 + 0.5 ).to_i
    else
      data_get( :account_total_due )
    end    
  end

  def add_internet_credit( client, internet_credit )
    dputs( 3 ){ "Adding #{internet_credit}CFA to #{client.internet_credit} for #{client.login_name}" }
    internet_credit_before = client.internet_credit
    if internet_credit.to_i < 0 and internet_credit.to_i.abs > client.internet_credit.to_i
      internet_credit = -client.internet_credit.to_i
    end
    client.data_set_log( :internet_credit, ( client.internet_credit.to_i + internet_credit.to_i ).to_s,
      "#{self.person_id}:#{internet_credit}" )
    pay_service( internet_credit, "internet_credit pour -#{client.login_name}:#{internet_credit}-")
    log_msg( "AddCash", "#{self.login_name} added #{internet_credit} for #{client.login_name}: " +
        "#{internet_credit_before} + #{internet_credit} = #{client.internet_credit}" )
    log_msg( "AddCash", "Total due: #{data_get :account_total_due}")
  end

  def pay_service( credit, msg )
    account_total_due = 0
    if @account_due
      Movements.create( "Automatic from Gestion: #{msg}", Time.now.strftime("%Y-%m-%d"), 
        credit.to_i / 1000.0, @account_due, @account_service )
      account_total_due = ( @account_due.total.to_f * 1000.0 + 0.5 ).to_i
    else
      account_total_due = data_get( :account_total_due ).to_i + credit.to_i
      data_set_log( :account_total_due, account_total_due, msg )
    end
  end

  def check_pass( pass )
    if @proxy.has_storage? :LDAP
      # We have to try to bind to the LDAP
      dputs( 0 ){ "Trying LDAP" }
      return @proxy.storage[:LDAP].check_login( data_get(:login_name), pass )
    else
      dputs( 0 ){ "is #{pass} equal to #{data_get( :password ) }" }
      return pass == data_get( :password )
    end
  end

  def services_active
    dputs( 4 ){ "Entering" }
    payments = Entities.Payments.search_by_client( self.id )
    if payments
      payments.select{|p|
        dputs( 3 ){ "Found payment for #{self.full_name}: #{p.inspect}" }
        if p.desc =~ /^Service:/
          service = Entities.Services.find_by_name( p.desc.gsub(/^Service:/, ''))
          dputs( 3 ){ "Found service #{service}" }
          service.duration == 0 or p.date + service.duration * 60 * 60 * 24 >= Time.now.to_i
        else
          false
        end
      }.collect{|p|
        p.desc.gsub(/^Service:/, '')
      }
    else
      []
    end
  end

  def password=(pass)
    if @proxy.has_storage? :LDAP
      dputs( 1 ){ "Changing password for #{self.login_name}: #{pass}" }
      pass = %x[ slappasswd -s #{pass} ]
      dputs( 1 ){ "Hashed password for #{self.login_name} is: #{pass}" }
    end
    dputs( 1 ){ "Setting password for #{self.login_name} to #{pass}" }
    data_set( :password, pass )
  end

  def full_name
    "#{self.first_name} #{self.family_name}"
  end

  def replace( orig, field, str )
    fields.each{|f|
      orig.gsub!( f[0], f[1].to_s )
    }
    orig
  end
  
  def lp_cmd=(v)
    @proxy.print_card.lp_cmd = v
  end

  def print( counter = nil )
    ctype = "Visiteur"
    courses = Courses.list_courses_for_person( self )
    if courses and courses.length > 0
      dputs(3){"Courses is #{courses.inspect}"}
      ctype = Courses.find_by_course_id( courses[0][0] ).description
    end
    fname = "#{person_id.to_s.rjust(6,'0')}-#{full_name.gsub(/ /,'_')}"
    @proxy.print_card.print( [ [ /--NOM--/, first_name ],
        [ /--NOM2--/, family_name ],
        [ /--BDAY--/, birthday ],
        [ /--TDAY--/, `LC_ALL=fr_FR.UTF-8 date +"%d %B %Y"` ],
        [ /--TEL--/, phone ],
        [ /--UNAME--/, login_name ],
        [ /--EMAIL--/, email ],
        [ /--CTYPE--/, ctype ],
        [ /--PASS--/, password_plain ] ], nil, fname )
  end

  def to_list
    [ login_name, "#{full_name} - #{login_name}:#{password_plain}"]
  end
	
  def session
    Sessions.find_by_sid( self.session_id )
  end
	
  def first_name=(v)
    data_set( :first_name, v.capitalize_all )
  end
	
  def family_name=(v)
    data_set( :family_name, v.capitalize_all )
  end
  
  def get_cash( person, amount )
    dputs(3){"Amount is #{amount.inspect} and #{person.inspect} will receive it"}
    amount = amount.to_i
    if amount < 0
      dputs(0){"Can't transfer a negative amount here"}
      return false
    end
    if not person.account_due
      dputs(0){"#{person.login_name}::#{person.full_name} has no account_due"}
      return false
    end
    if not @account_cash
      dputs(0){"#{self.inspect} has no account_cash"}
      return false
    end
    dputs(3){"Transferring #{amount} from #{@account_cash.get_path} to " +
        "#{person.account_due.get_path}"
    }
    Movements.create( "Payement au comptable", Date.today,
      amount / 1000.0, @account_cash, person.account_due )
    return true
  end
  
  def can_view( v )
    Permission.can_view( data_get(:permissions), v )
  end
end
