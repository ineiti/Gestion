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
      :permissions => [ "admin" ], :account_name_due => "Linus" )
    @josue = Entities.Persons.create( :login_name => "josue", :password => "super",
      :permissions => %w( default admin secretary ), :account_name_due => "Josué" )
    @surf = Entities.Persons.create( :login_name => "surf", :password => "super",
      :permissions => [ "default" ] )
    @secretary = Entities.Persons.create( :login_name => "secr",
      :permissions => ["secretary"] )
    @teacher = Entities.Persons.create( :login_name => "teacher",
      :permissions => ["professor"] )
    @center = Persons.create( :login_name => "foo", :permissions => ["center"] )

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
    assert_equal @josue, Entities.Persons.match_by_login_name( "josue" )
    assert_equal @surf, Entities.Persons.match_by_login_name( "surf" )
    assert_equal @admin, Entities.Persons.match_by_login_name( "admin" )
    Sessions.create( @surf )
    session = Sessions.create( @josue )

    surf_credit = @surf.internet_credit.to_i
    josue_due = @josue.account_total_due.to_i
    dputs( 0 ){ "surf_credit: #{surf_credit} - josue_due: #{josue_due}" }
    # Josue puts 500 on "surf"s account
    View.PersonCredit.rpc_button( session, "add_credit",
      {'person_id' => 2, 'login_name' => 'surf', 'credit_add' => 500 } )
    assert_equal 500, @surf.internet_credit.to_i - surf_credit, "Credit"
    assert_equal 500, @josue.account_total_due.to_i - josue_due, "account_total_due"
    dputs( 0 ){ "surf.log_list is #{@surf.log_list.inspect}" }
    dputs( 0 ){ "josue.log_list #{@josue.log_list.inspect}" }
    log_list = [ @surf.log_list.last, @josue.log_list.last]
    dputs( 0 ){ "log_list #{log_list.inspect}" }
    log_list.undate
    log_list.unlogid
    assert_equal( {:data_class_id=>3, :data_field=>:internet_credit, :data_value=>"500",
        :undo_function=>:undo_set_entry, :data_class=>"Person",
        :msg=>"2:500", :data_old=>0},
      log_list[0].unlogid )
    assert_equal( {:data_value=>josue_due + 500, :undo_function=>:undo_set_entry,
        :data_old=>josue_due, :data_class_id=>2,
        :data_class=>"Person", :msg=>"internet_credit pour -surf:500-", :data_field=>:account_total_due},
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

    @name2 = Entities.Persons.create( {:first_name => "one two three four"})
    assert_equal "One Two", @name2.first_name
    assert_equal "Three Four", @name2.family_name
    assert_equal "tone2", @name2.login_name
  end

  def tesst_print
    @admin.print
  end

  def tesst_print_accent
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
      @admin.log_list[-2].undate.unlogid )
  end

  def test_log_change
    @admin.first_name = "super"
    assert_equal( {:data_class_id=>1,
        :data_field=>:first_name,
        :data_value=>"Super",
        :data_class=>"Person",
        :undo_function=>:undo_set_entry,
        :data_old=>"admin",
        :msg=>nil},
      @admin.log_list[-1].undate.unlogid )
  end
  
  def test_account_due
    @secretary = Entities.Persons.create( :login_name => "secretary",
      :permissions => ["secretary"] )
  
    assert_equal "Secretary", @secretary.account_name_due, @secretary.inspect
    
    assert_equal nil, @surf.account_name_due

    @surf.permissions = %w( default secretary )
    assert_equal "Surf", @surf.account_name_due
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
    
    internet_credit = @josue.account_total_due
    @josue.add_internet_credit( @surf, 1000 )
    assert_equal 1000, @josue.account_total_due - internet_credit
    
    assert @accountant.get_cash( @josue, 1000 )
    assert_equal 0, @josue.account_total_due - internet_credit
    assert_equal 0, @accountant2.total_cash.to_f
  end
  
  def test_account_cash_update
    assert_equal nil, @surf.account_cash
    
    @surf.permissions = %w( default accountant )
    assert_not_nil @surf.account_cash
  end
  
  def test_listp_account_due
    list = Persons.listp_account_due
    assert list
  end
  
  def test_has_all_rights
    assert_equal [".*", "FlagAddInternet", "Internet", "PersonModify",
      "PersonShow", "View", "Welcome"], Permission.views( @josue.permissions )
    assert_equal ["FlagAddInternet", "Internet", "PersonModify",
      "PersonShow", "View", "Welcome"], Permission.views( @secretary.permissions )
    assert_equal ["View", "Welcome"], Permission.views( @surf.permissions )
    assert_equal ["Internet", "PersonShow", "View", "Welcome"], 
      Permission.views( @teacher.permissions )
    assert_equal true, @admin.has_all_rights_of( @josue )
    assert_equal true, @josue.has_all_rights_of( @admin )
    assert_equal true, @admin.has_all_rights_of( @secretary )
    assert_equal false, @secretary.has_all_rights_of( @admin )
    assert_equal true, @josue.has_all_rights_of( @secretary )
    assert_equal false, @secretary.has_all_rights_of( @josue )
    assert_equal true, @secretary.has_all_rights_of( @surf )
    assert_equal false, @teacher.has_all_rights_of( @secretary )
  end
  
  def test_permission_sort
    assert_equal ["accountant", "admin", "center", "default", "internet",
      "professor", "secretary", "student"], 
      View.PersonAdmin.layout_find( "permissions" ).to_a[3][:list_values]
  end
  
  def test_has_permission
    assert @secretary.has_permission? :secretary
    assert @secretary.has_permission? "secretary"
    assert @secretary.has_permission? :PersonModify
    assert @secretary.has_permission? "PersonModify"
    assert @secretary.has_permission? :Internet
    assert @secretary.has_permission? "Internet"
    assert ! @secretary.has_permission?( :FlagAccounting )
    assert ! @secretary.has_permission?( "FlagAccounting" )
    assert ! @secretary.has_permission?( :admin )
    assert ! @secretary.has_permission?( "admin" )
  end
  
  def test_delete
    @maint = Courses.create( :name => "maint_1201")
    @grade = Grades.save_data( :course => @maint,
      :student => @surf, :means => [12])
  
    assert_equal 1, Grades.matches_by_student( @surf ).length, Grades.data.inspect
    
    @surf.delete
  
    assert_equal 0, Grades.matches_by_student( @surf ).length
  end
  
  def test_delete_needed
    @maint = Courses.create( :name => "maint_1201", :teacher => @admin )

    begin
      @admin.delete
    rescue IsNecessary => who
      assert_equal "maint_1201", who.for_course.name
    end
  end

#  def test_multilogin
#    assert_equal nil, Views.Welcome.rpc_show( nil )
#  end

  def test_cash_msg
    data = {"copies_laser"=>"0", "heures_groupe_grand"=>"", "CDs"=>nil, 
      "autres_text"=>"", "autres_cfa"=>""}
    assert_equal "{}", SelfServices.cash_msg( data )
    
    data["copies_laser"] = 100
    assert_equal "{\"copies_laser\"=>\"100\"}", SelfServices.cash_msg( data )
    
    data["copies_laser"] = 0
    data["autres_text"] = "électricité"
    data["autres_cfa"] = 1000
    assert_equal "{\"autres_cfa\"=>\"1000\"}", SelfServices.cash_msg( data )
  end
end
