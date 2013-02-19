require 'test/unit'

class Array
  def undate
    self.each{|l| l.undate}
    self
  end
  def unlogid
    self.each{|l| l.unlogid}
    self
  end
end

class Hash
  def undate
    self.delete( :date_stamp )
    self
  end
  def unlogid
    self.delete( :logaction_id )
    self
  end
end

class TC_Person < Test::Unit::TestCase
  def send_to_sqlite_users( m )
    Entities.Movements.send( m.to_sym )
    Entities.Accounts.send( m.to_sym )
    Entities.Users.send( m.to_sym )
  end
  
  def setup
    #Permission.add( 'default', '.*' )

    dputs(0){"Setting up"}
    Entities.delete_all_data()

    dputs(0){"Resetting SQLite"}
    SQLite.dbs_close_all
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    SQLite.dbs_open_load_migrate

    @admin = Entities.Persons.create( :login_name => "admin", :password => "super123",
      :permissions => [ "default" ], :account_due => "Linus" )
    @josue = Entities.Persons.create( :login_name => "josue", :password => "super",
      :permissions => %w( default addinternet secretary ), :account_due => "Josué" )
    @surf = Entities.Persons.create( :login_name => "surf", :password => "super",
      :permissions => [ "default" ] )
    Entities.Services.create( :name => "surf", :price => 1000, :duration => 20 )
    Entities.Services.create( :name => "solar", :price => 1000, :duration => 20 )
    Entities.Services.create( :name => "club", :price => 1000, :duration => 0 )
    Entities.Payments.create( :desc => "Service:surf", :date => ( Time.now - 60 * 60 * 24 * 21 ).to_i,
      :client => @surf.id )
    Entities.Payments.create( :desc => "Service:solar", :date => ( Time.now - 60 * 60 * 24 * 19 ).to_i,
      :client => @surf.id )
    Entities.Payments.create( :desc => "Service:club", :date => ( Time.now - 60 * 60 * 24 * 19 ).to_i,
      :client => @josue.id )
    Entities.Payments.create( :desc => "Service:surf", :date => ( Time.now - 60 * 60 * 24 * 19 ).to_i,
      :client => @josue.id )
  end

  def teardown
    #permissions_init
    Entities.Persons.save
    Entities.LogActions.save
  end

  def test_addcash
    @josue.disable_africompta
    @surf.disable_africompta
    assert_equal @josue, Entities.Persons.find_by_login_name( "josue" )
    assert_equal @surf, Entities.Persons.find_by_login_name( "surf" )
    assert_equal @admin, Entities.Persons.find_by_login_name( "admin" )
    Sessions.create( @surf )
    session = Sessions.create( @josue )

    surf_credit = @surf.credit.to_i
    josue_due = @josue.credit_due.to_i
    dputs( 0 ){ "surf_credit: #{surf_credit} - josue_due: #{josue_due}" }
    # Josue puts 500 on "surf"s account
    View.PersonCredit.rpc_button( session, "add_credit",
      {'person_id' => 2, 'login_name' => 'surf', 'credit_add' => 500 } )
    assert_equal 500, @surf.credit.to_i - surf_credit, "Credit"
    assert_equal 500, @josue.credit_due.to_i - josue_due, "Credit_due"
    dputs( 0 ){ "surf.log_list is #{@surf.log_list.inspect}" }
    dputs( 0 ){ "josue.log_list #{@josue.log_list.inspect}" }
    log_list = [ @surf.log_list.last, @josue.log_list.last]
    dputs( 0 ){ "log_list #{log_list.inspect}" }
    log_list.undate
    log_list.unlogid
    assert_equal( {:data_class_id=>3, :data_field=>:credit, :data_value=>"500",
        :undo_function=>:undo_set_entry, :data_class=>"Person",
        :msg=>"2:500", :data_old=>0},
      log_list[0].unlogid )
    assert_equal( {:data_value=>josue_due + 500, :undo_function=>:undo_set_entry,
        :data_old=>josue_due, :data_class_id=>2,
        :data_class=>"Person", :msg=>"credit pour -surf:500-", :data_field=>:credit_due},
      log_list[1].unlogid )
  end

  def test_services
    # TODO:
    # re-add services
    return
    assert_equal ["club","surf"], @josue.services_active
    assert_equal ["solar"], @surf.services_active
  end

  def test_accents
    @bizarre1 = Entities.Persons.create( {:first_name => "éaënne", :family_name => "ässer"})
    @bizarre2 = Entities.Persons.create( {:first_name => "@hello", :family_name => "wœrld#"})
    assert_equal "aeaenne", @bizarre1.login_name
    assert_equal "w_hello", @bizarre2.login_name
  end

  def test_creation
    @name1 = Entities.Persons.create( {:first_name => "one two three"})
    assert_equal "One", @name1.first_name
    assert_equal "Two Three", @name1.family_name
  end

  def test_print
    @admin.print
  end

  def test_print_accent
    @accents = Entities.Persons.create( {:first_name => "éaënne", :family_name => "ässer"})
    @accents.print
  end

  def test_log_password
    @admin.password = "admin"
    assert_equal( {:data_class_id=>1,
        :data_field=>:password,
        :data_value=>"admin",
        :data_class=>"Person",
        :undo_function=>:undo_set_entry,
        :data_old=>"super123",
        :msg=>nil},
      @admin.log_list[-1].undate.unlogid )
  end

  def test_log_change
    @admin.first_name = "super"
    assert_equal( {:data_class_id=>1,
        :data_field=>:first_name,
        :data_value=>"Super",
        :data_class=>"Person",
        :undo_function=>:undo_set_entry,
        :data_old=>nil,
        :msg=>nil},
      @admin.log_list[-1].undate.unlogid )
  end
  
  def test_account_due
    @secretary = Entities.Persons.create( :login_name => "secretary",
      :permissions => ["secretary"] )
  
    assert_equal "Secretary", @secretary.account_due
  end
  
  def test_account_cash
    @accountant = Entities.Persons.create( :login_name => "accountant", :password => "super",
      :permissions => [ "accountant" ] )
    @accountant2 = Entities.Persons.create( :login_name => "accountant2", :password => "super",
      :permissions => [ "accountant" ] )
    
    assert_equal "Accountant", @accountant.account_name_cash

    assert_not_nil @accountant.account_cash
    assert_equal "Root::Cash::Accountant", @accountant.account_cash.get_path
    assert_equal 0, @accountant.total_cash.to_f
    assert_equal 0, @accountant2.total_cash.to_f
    
    credit = @josue.credit_due
    @josue.add_credit( @surf, 1000 )
    assert_equal 1000, @josue.credit_due - credit
    
    assert @accountant.get_cash( @josue, 1000 )
    assert_equal 0, @josue.credit_due - credit
    assert_equal 0, @accountant2.total_cash.to_f
  end
  
  def test_account_cash_update
    assert_equal nil, @josue.account_cash
    
    @josue.permissions = %w( default accounting )
    assert_not_nil @josue.account_cash
  end
  
  def test_listp_compta_due
    list = Persons.listp_compta_due
    assert list
  end
end
