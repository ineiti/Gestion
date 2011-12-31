require 'test/unit'

Permission.add( 'default', '.*' )

class TC_Person < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
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
    View.Welcome.add_session( @surf )
    session = View.Welcome.add_session( @josue )

    surf_credit = @surf.credit.to_i
    josue_due = @josue.credit_due.to_i
    dputs 0, "surf_credit: #{surf_credit} - josue_due: #{josue_due}"
    # Josue puts 500 on "surf"s account
    View.CashAdd.rpc_button_add_cash( session, {'person_id' => 2, 'login_name' => 'surf',
      'credit_add' => 500 } )
    assert_equal 500, @surf.credit.to_i - surf_credit
    assert_equal 500, @josue.credit_due.to_i - josue_due
    dputs 0, @surf.log_list.inspect
    dputs 0, @josue.log_list.inspect
    log_list = [ @surf.log_list[2], @josue.log_list[3]]
    dputs 0, log_list.inspect
    log_list.each{|l| l.delete( :date_stamp )}
    assert_equal( {:data_class_id=>2, :data_field=>:credit, :data_value=>"500",
      :logaction_id=>7, :undo_function=>:undo_set_entry, :data_class=>Person,
      :msg=>"1:500", :data_old=>"null"},
    log_list[0])
    assert_equal( {:data_value=>josue_due + 500, :undo_function=>:undo_set_entry, 
      :logaction_id=>8, :data_old=>josue_due.to_s, :data_class_id=>1, 
      :data_class=>Person, :msg=>"credit pour -surf:500-", :data_field=>:credit_due},
    log_list[1] )
  end
  
  def test_services
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
end
