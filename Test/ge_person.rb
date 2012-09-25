require 'test/unit'

class Array
  def undate
    self.each{|l| l.undate}
    self
  end
end

class Hash
  def undate
    self.delete( :date_stamp )
    self
  end
end

Permission.add( 'default', '.*' )

class TC_Person < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
		FileUtils.cp( "db.testGestion", "data/compta.db" )

		Entities.Movements.load
		Entities.Accounts.load
		Entities.Users.load

    @admin = Entities.Persons.create( :login_name => "admin", :password => "super123",
			:permissions => [ "default" ], :account_due => "Linus" )
    @josue = Entities.Persons.create( :login_name => "josue", :password => "super",
			:permissions => [ "default" ], :account_due => "Josué" )
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
    Entities.Persons.save
    Entities.LogActions.save
  end

  def test_addcash
    assert_equal @josue, Entities.Persons.find_by_login_name( "josue" )
    assert_equal @surf, Entities.Persons.find_by_login_name( "surf" )
    assert_equal @admin, Entities.Persons.find_by_login_name( "admin" )
    Session.new( @surf )
    session = Session.new( @josue )

    surf_credit = @surf.credit.to_i
    josue_due = @josue.credit_due.to_i
    dputs 0, "surf_credit: #{surf_credit} - josue_due: #{josue_due}"
    # Josue puts 500 on "surf"s account
    View.PersonModify.rpc_button( session, "add_credit",
			{'person_id' => 2, 'login_name' => 'surf', 'credit_add' => 500 } )
    assert_equal 500, @surf.credit.to_i - surf_credit, "Credit"
    assert_equal 500, @josue.credit_due.to_i - josue_due, "Credit_due"
    dputs 0, @surf.log_list.inspect
    dputs 0, @josue.log_list.inspect
    log_list = [ @surf.log_list[2], @josue.log_list[3]]
    dputs 0, log_list.inspect
    log_list.undate
    assert_equal( {:data_class_id=>2, :data_field=>:credit, :data_value=>"500",
				:logaction_id=>15, :undo_function=>:undo_set_entry, :data_class=>"Person",
				:msg=>"1:500"},
			log_list[0])
    assert_equal( {:data_value=>josue_due + 500, :undo_function=>:undo_set_entry,
				:logaction_id=>22, :data_old=>josue_due, :data_class_id=>1,
				:data_class=>"Person", :msg=>"credit pour -surf:500-", :data_field=>:credit_due},
			log_list[1] )
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

  def test_log_password
    @admin.password = "admin"
    assert_equal( {:data_class_id=>0,
				:data_field=>:password,
				:data_value=>"admin",
				:data_class=>"Person",
				:undo_function=>:undo_set_entry,
				:data_old=>"super123",
				:logaction_id=>13},
			@admin.log_list[-1].undate )
  end

  def test_log_change
    @admin.first_name = "super"
    assert_equal( {:data_class_id=>0,
				:data_field=>:first_name,
				:data_value=>"super",
				:data_class=>"Person",
				:undo_function=>:undo_set_entry,
				:logaction_id=>13},
			@admin.log_list[-1].undate )
  end
end
