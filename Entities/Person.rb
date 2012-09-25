# Holds the data available for a person. The permission is a regexp
# giving access to different views and it's blocks
#
# Configuration:
# adduser_cmd - is called after ldapadduser returns with the username as argument

require 'OpenPrint'



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
    value_str :account_due
    value_list :permissions, "Permission.list"

    value_block :internet
    value_list :groups, "%w( freeadsl sudo print )"
    value_list_single_LDAP :internet_none, "[]", :ldap_name => "man-internet-none"

    value_block :read_only
    value_str_ro_LDAP :login_name, :ldap_name => "uid"
    value_int_ro_LDAP :credit, :ldap_name => "man-internet-cash"
    value_int_ro :credit_due

    value_block :hidden
    value_str :session_id
    value_str_LDAP :password, :ldap_name => "userPassword"
    value_str :password_plain
    value_int_LDAP :person_id, :ldap_name => "uidnumber"

    dputs 0, $config.inspect
    if $config[:DiplomaDir]
      @print_card = OpenPrint.new( "#{$config[:DiplomaDir]}/carte_etudiant.odg" )
    end

    LOAD_DATA
  end

  # Searches for an empty name starting with "login", adding 2, 3, 4, ...
  def find_empty_login_name( login )
    suffix = ""
    login = accents_replace( login )
    while find_by_login_name( login + suffix.to_s )
      dputs 2, "Found #{login + suffix.to_s} to already exist"
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
      dputs 1, "Creating user #{names.inspect} as #{first} - #{family}"
      [ first, family ]
    else
      [ fullname, "" ]
    end
  end

  def accents_replace( login )
    login = login.downcase.gsub( / /, "_" )
    accents = Hash[ *%w( a àáâä e éèêë i ìíîï o òóôöœ u ùúûü c ç ss ß )]
    dputs 2, "Login was #{login}"
    accents.each{|k,v|
      login.gsub!( /[#{v}]/, k )
    }
    login.gsub!( /[^a-z0-9_-]/, '_' )
    dputs 2, "Login is #{login}"
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
      dputs 2, "Family name + First name"
			login = family.chars.first + first
    else
			login = first
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
    dputs 1, "Creating #{d.inspect}"

    person = super( d )

    person.password_plain = d.has_key?( :password ) ? d[:password] : rand( 10000 ).to_s.rjust(4,"0")
    person.password = person.password_plain

    if defined? @cmd_after_new
      dputs 2, "Going to call #{@cmd_after_new}"
      %x[ #{@cmd_after_new} #{person.login_name} #{person.password_plain} ]
    end

    return person
  end

  def self.create_empty
    Entities.Persons.create( [] )
  end

  def update( session )
    super( session ).merge( { :credit_due => session.owner.get_credit } )
  end

  # Adds cash to a persons account. The hash "data" should contain the following
  # fields:
  # - credit_add : how much CFA to add
  # - person_id : the id of the person to receive the credit
  def add_cash( session, data )
    dputs 5, "data is #{data.inspect}"
    if data['credit_add'] and data['person_id']
      actor = session.owner
      client = find_by_person_id( data['person_id'].to_s )
      dputs 3, "Adding cash to #{client.full_name} from #{actor.full_name}"
      if client
        actor.add_credit( client, data['credit_add'])
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

  def save_data( d )
    d = d.to_sym
    dputs 3, "d is #{d.inspect}"

    if ! d[:first_name] and ! d[:person_id]
      return { :first_name => "user" }
    end

    super( d )
  end

  def data_create( data )
    dputs 0, "Creating new data #{data.inspect}"
    dputs 0, @adduser_cmd
    if has_storage? :LDAP
      user = data[:login_name]
      if %x[ ldapadduser #{user} plugdev ] and defined? @adduser_cmd
        dputs 0, @adduser_cmd
        %x[ #{@adduser_cmd} #{user} ]
      end
    end
  end

  def find_full_name( name )
    dputs 2, "Searching for #{name}"
    @data.each_key{|k|
      if @data[k]
        fn = "#{data[k][:first_name]} #{data[k][:family_name]}"
        dputs 2, "Searching in #{fn}"
        if fn =~ /#{name}/i
          dputs 2, "Found it"
          return get_data_instance(k)
        end
      end
    }
    return nil
  end

  def find_name_or_create( name )
    first, last = name.split( " ", 2 )
    find_full_name( name ) or
			person = create( :first_name => first, :family_name => last )
  end

  def login_to_full( login )
    p = find_by_login_name( login )
    p ? p.full_name : ""
  end
end



#
### One person only
#

class Person < Entity
  attr_accessor :compta_due
  def setup_instance
    update_account_due
  end

  def update_account_due
    c = get_config( "Root::Lending", :compta_due, :src )
    if data_get( :account_due )
      src = "#{c}::#{data_get(:account_due)}"
      dputs 2, "Creating AfriCompta with source-account: #{src}"
      @compta_due = AfriCompta.new( src, 
				get_config( "Root::Income", :compta_due, :dst ) )
      update_credit
    else
      @compta_due = AfriCompta.new
    end
  end

  def data_set(field, value, msg = nil, undo = true, logging = true )
    old_value = data_get(field)
    if old_value != value
      dputs 0, "Saving #{field} = #{value}"
      if logging
        if undo
          @proxy.log_action( @id, { field => value }, msg, :undo_set_entry, old_value )
        else
          @proxy.log_action( @id, { field => value }, msg )
        end
      end
    end
    ret = super( field, value )
    if field and field.to_s == "account_due"
      update_account_due
    end
    return ret
  end

  def data_set_log(field, value, msg = nil, undo = true, logging = true )
    data_set( field, value, msg, undo, logging )
  end

  def get_credit
    if @compta_due and not @compta_due.disabled
			dputs 2, "credit is #{@compta_due.get_credit}"
			( @compta_due.get_credit * 1000.0 + 0.5 ).to_i
		else
			self.credit_due
		end
  end

  def update_credit
    self.credit_due = get_credit
    self.credit_due = 0 if not self.credit_due
  end

  def add_credit( client, credit )
    dputs 3, "Adding #{credit}CFA to #{client.credit} for #{client.login_name}"
    credit_before = client.credit
    if credit.to_i < 0 and credit.to_i.abs > client.credit.to_i
			credit = -client.credit.to_i
    end
    client.data_set_log( :credit, ( client.credit.to_i + credit.to_i ).to_s,
			"#{self.person_id}:#{credit}" )
    move_cash( credit, "credit pour -#{client.login_name}:#{credit}-")
    log_msg( "AddCash", "#{self.login_name} added #{credit} for #{client.login_name}: " +
        "#{credit_before} + #{credit} = #{client.credit}" )
    log_msg( "AddCash", "Total due: #{self.credit_due}")
  end

  def move_cash( credit, msg )
    credit_due = 0
    if @compta_due and not @compta_due.disabled
      credit_due = @compta_due.add_movement( credit.to_i / 1000.0,
				"Gestion: #{msg}" )
			credit_due = ( credit_due * 1000.0 + 0.5 ).to_i
    else
			credit_due = self.credit_due.to_i + credit.to_i
    end
    data_set_log( :credit_due, credit_due, msg )
  end

  def check_pass( pass )
    if @proxy.has_storage? :LDAP
      # We have to try to bind to the LDAP
      dputs 0, "Trying LDAP"
      return @proxy.storage[:LDAP].check_login( data_get(:login_name), pass )
    else
      dputs 0, "is #{pass} equal to #{data_get( :password ) }"
      return pass == data_get( :password )
    end
  end

  def services_active
    dputs 4, "Entering"
    payments = Entities.Payments.search_by_client( self.id )
    if payments
      payments.select{|p|
        dputs 3, "Found payment for #{self.full_name}: #{p.inspect}"
        if p.desc =~ /^Service:/
          service = Entities.Services.find_by_name( p.desc.gsub(/^Service:/, ''))
          dputs 3, "Found service #{service}"
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
      dputs 1, "Changing password for #{self.login_id}: #{pass}"
      pass = %x[ slappasswd -s #{pass} ]
      dputs 1, "Hashed password for #{self.login_id} is: #{pass}"
    end
    dputs 1, "Setting password for #{self.login_id} to #{pass}"
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

  def print( counter = nil )
    @proxy.print_card.print( [ [ /--NOM--/, first_name ],
				[ /--NOM2--/, family_name ],
				[ /--BDAY--/, birthday ],
				[ /--TDAY--/, `LC_ALL=fr_FR.UTF-8 date +"%d %B %Y"` ],
				[ /--TEL--/, phone ],
				[ /--UNAME--/, login_name ],
				[ /--EMAIL--/, email ],
				[ /--PASS--/, password_plain ] ], counter )
  end

  def to_list
    [ login_name, "#{full_name} - #{login_name}:#{password_plain}"]
  end
end
