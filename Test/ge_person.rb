require 'test/unit'

class Array
  def undate
    self.each { |l| l.undate }
    self
  end
end

class Hash
  def undate
    self.delete(:date_stamp)
    self
  end
end

class TC_Person < Test::Unit::TestCase
  def send_to_sqlite_users(m)
    Entities.Movements.send(m.to_sym)
    Entities.Accounts.send(m.to_sym)
    Entities.Users.send(m.to_sym)
  end

  def setup
    permissions_init

    dputs(1) { 'Setting up' }
    Entities.delete_all_data
    dputs(2) { 'Resetting SQLite' }
    SQLite.dbs_close_all
    FileUtils.cp('db.testGestion', 'data/compta.db')
    SQLite.dbs_open_load_migrate

    ConfigBases.init

    @admin = Entities.Persons.create(:login_name => 'admin', :password => 'super123',
                                     :permissions => ['admin'], :account_name_due => 'Linus')
    @josue = Entities.Persons.create(:login_name => 'josue', :password => 'super',
                                     :permissions => %w( default director secretary ),
                                     :account_due => Accounts.create_path('Root::Lending::Josué'))
    @surf = Entities.Persons.create(:login_name => 'surf', :password => 'super',
                                    :permissions => ['default'])
    @student = Entities.Persons.create(:login_name => 'student', :password => 'super',
                                       :permissions => ['student'])
    @student2 = Entities.Persons.create(:login_name => 'student2', :password => 'super',
                                        :permissions => ['student'])
    @secretary = Entities.Persons.create(:login_name => 'secr',
                                         :permissions => ['secretary'])
    @teacher = Entities.Persons.create(:login_name => 'teacher',
                                       :permissions => ['teacher'])
    @center = Persons.create(:login_name => 'foo', :permissions => ['center'])
    @accountant = Persons.create(:login_name => 'accountant',
                                 :permissions => ['accountant'])

  end

  def teardown
  end

  def test_responsibles
    resps = Persons.responsibles
    assert_equal [[8, 'Foo'], [2, 'Josue'], [6, 'Secr'], [7, 'Teacher']], resps
    @surf.permissions = @surf.permissions + ['teacher']
    assert_equal [[8, 'Foo'], [2, 'Josue'], [6, 'Secr'], [3, 'Surf'], [7, 'Teacher']],
                 Persons.responsibles
    assert Persons.resps != []
  end

  def test_addcash
    @josue.disable_africompta
    @surf.disable_africompta
    assert_equal @josue, Entities.Persons.match_by_login_name('josue')
    assert_equal @surf, Entities.Persons.match_by_login_name('surf')
    assert_equal @admin, Entities.Persons.match_by_login_name('admin')
    Sessions.create(@surf)
    session = Sessions.create(@josue)

    surf_credit = @surf.internet_credit.to_i
    josue_due = @josue.account_total_due.to_i
    dputs(1) { "surf_credit: #{surf_credit} - josue_due: #{josue_due}" }
    # Josue puts 500 on "surf"s account
    View.CashboxCredit.rpc_button(session, 'add_credit',
                                 {'person_id' => 2, 'login_name' => 'surf', 'credit_add' => 500})
    assert_equal 500, @surf.internet_credit.to_i - surf_credit, 'Credit'
    assert_equal -500, @josue.account_total_due.to_i - josue_due, 'account_total_due'
  end

  def test_accents
    @bizarre1 = Entities.Persons.create({:first_name => 'éaënne', :family_name => 'ässer'})
    @bizarre2 = Entities.Persons.create({:first_name => '@hello', :family_name => 'wœrld#'})
    assert_equal 'aeaenne', @bizarre1.login_name
    assert_equal 'w_hello', @bizarre2.login_name
  end

  def test_creation
    @name1 = Entities.Persons.create({:first_name => 'one two three'})
    assert_equal 'One', @name1.first_name
    assert_equal 'Two Three', @name1.family_name

    @name2 = Entities.Persons.create({:first_name => 'one two three four'})
    assert_equal 'One Two', @name2.first_name
    assert_equal 'Three Four', @name2.family_name
    assert_equal 'tone2', @name2.login_name
  end

  def tesst_print
    @admin.print
  end

  def tesst_print_accent
    @accents = Entities.Persons.create({:first_name => 'éaënne', :family_name => 'ässer'})
    @accents.print
  end

  # Problem with test_permissions
  def test_account_due
    ConfigBase.store(functions: %w(accounting accounting_courses))
    @secretary = Entities.Persons.create(:login_name => 'secretary',
                                         :permissions => ['secretary'])

    assert_equal 'Root::Lending::Secretary',
                 @secretary.account_due.get_path, @secretary.inspect

    assert_equal nil, @surf.account_due

    @surf.permissions = %w( default secretary )
    assert_equal 'Root::Lending::Surf', @surf.account_due.get_path
  end

  def test_account_cash
    ConfigBase.store(functions: %w(accounting accounting_courses))
    @accountant = Persons.create(:login_name => 'acc', :password => 'super',
                                 :permissions => ['accountant'])
    @accountant2 = Persons.create(:login_name => 'acc2', :password => 'super',
                                  :permissions => ['accountant'])

    assert_not_nil @accountant.account_cash
    assert_equal 'Root::Cash::Acc', @accountant.account_cash.get_path
    assert_equal 0, @accountant.total_cash.to_f
    assert_equal 0, @accountant2.total_cash.to_f

    internet_credit = @josue.account_total_due
    @josue.add_internet_credit(@surf, 1000)
    assert_equal -1000, @josue.account_total_due - internet_credit

    assert @accountant.get_cash(@josue, 1000)
    assert_equal 0, @josue.account_total_due - internet_credit
    assert_equal 0, @accountant2.total_cash.to_f
  end

  def test_account_cash_update
    ConfigBase.store(functions: %w(accounting accounting_courses))

    assert_equal nil, @surf.account_cash

    @surf.permissions = %w( default accountant )
    assert_not_nil @surf.account_cash
  end

  def test_listp_account_due
    ConfigBase.store(functions: %w(accounting accounting_courses))

    list = Persons.listp_account_due
    assert_equal [[6, '     0 - Secr'], [2, '     0 - Josue']], list
  end

  def test_has_all_rights
    assert_equal %w(FlagAddCenter FlagAddInternet FlagResponsible Internet PersonCredit
                  PersonModify PersonShow View Welcome),
                 Permission.views(@josue.permissions)
    assert_equal %w(FlagAddInternet FlagResponsible Internet PersonCredit
                  PersonModify PersonShow View Welcome),
                 Permission.views(@secretary.permissions)
    assert_equal %w(View Welcome), Permission.views(@surf.permissions)
    assert_equal %w(FlagResponsible Internet PersonShow View Welcome),
                 Permission.views(@teacher.permissions)
    assert_equal true, @admin.has_all_rights_of(@josue)
    assert_equal false, @josue.has_all_rights_of(@admin)
    assert_equal true, @admin.has_all_rights_of(@secretary)
    assert_equal false, @secretary.has_all_rights_of(@admin)
    assert_equal true, @josue.has_all_rights_of(@secretary)
    assert_equal false, @secretary.has_all_rights_of(@josue)
    assert_equal true, @secretary.has_all_rights_of(@surf)
    assert_equal false, @teacher.has_all_rights_of(@secretary)
  end

  def test_permission_sort
    assert_equal %w(accountant admin center default director internet secretary student teacher),
                 View.PersonAdmin.layout_find('permissions').to_a[3][:list_values].sort
  end

  def test_has_permission
    assert @secretary.has_permission? :secretary
    assert @secretary.has_permission? 'secretary'
    assert @secretary.has_permission? :PersonModify
    assert @secretary.has_permission? 'PersonModify'
    assert @secretary.has_permission? :Internet
    assert @secretary.has_permission? 'Internet'
    assert !@secretary.has_permission?(:FlagAccounting)
    assert !@secretary.has_permission?('FlagAccounting')
    assert !@secretary.has_permission?(:admin)
    assert !@secretary.has_permission?('admin')
  end

  def test_delete
    @maint = Courses.create(:name => 'maint_1201')
    @grade = Grades.save_data(:course => @maint,
                              :student => @surf, :means => [12])

    assert_equal 1, Grades.matches_by_student(@surf).length, Grades.data.inspect

    @surf.delete

    assert_equal 0, Grades.matches_by_student(@surf).length
  end

  def test_delete_needed
    @maint = Courses.create(:name => 'maint_1201', :teacher => @admin)

    begin
      @admin.delete
    rescue IsNecessary => who
      assert_equal 'maint_1201', who.for_course.name
    end
  end

  #  def test_multilogin
  #    assert_equal nil, Views.Welcome.rpc_show( nil )
  #  end

  def test_cash_msg
    data = {'copies_laser' => '0', 'heures_groupe_grand' => '', 'CDs' => nil,
            'autres_text' => '', 'autres_cfa' => ''}
    assert_equal '{}', SelfServices.cash_msg(data)

    data['copies_laser'] = 100
    assert_equal "{\"copies_laser\"=>\"100\"}", SelfServices.cash_msg(data)

    data['copies_laser'] = 0
    data['autres_text'] = 'électricité'
    data['autres_cfa'] = 1000
    assert_equal "{\"autres_cfa\"=>\"1000\"}", SelfServices.cash_msg(data)
  end

  def test_report_pdf
    ConfigBase.add_function(:accounting_courses)
    assert @secretary.account_due

    ctype = CourseTypes.create(:name => 'base',
                               :account_base => Accounts.create_path('Root::Income::Courses'))
    course = Courses.create_ctype(ctype, '1404')
    assert course.entries

    date = Date.new(2014, 4, 10)
    Movements.create('test', date - 1, 10, course.entries, @secretary.account_due)
    Movements.create('test', date, 20.1, course.entries, @secretary.account_due)
    Movements.create('test', date - 2, 30, course.entries, @secretary.account_due)

    file = @secretary.report_pdf(3)

    assert file
    ConfigBase.del_function(:accounting_courses)
  end

  def test_get_all_due
    ConfigBase.add_function(:accounting_courses)
    service = ConfigBase.account_services

    assert_equal 0, @secretary.account_due.total.to_f
    assert_equal 0, @secretary.account_due_paid.total.to_f
    assert_equal 0, service.total.to_f
    assert_equal 0, @accountant.account_cash.total.to_f

    @secretary.pay_service(10000, 'test1')
    @secretary.pay_service(1000, 'test2')
    assert_equal 11.0, @secretary.account_due.total.to_f
    assert_equal 0, @secretary.account_due_paid.total.to_f
    assert_equal 11.0, service.total.to_f

    @accountant.get_all_due(@secretary)
    assert_equal 11.0, @accountant.account_cash.total.to_f
    assert_equal 0, @secretary.account_due.total.to_f
    assert_equal 0, @secretary.account_due_paid.total.to_f
    assert_equal 11.0, service.total.to_f

    ConfigBase.del_function(:accounting_courses)
  end

  def test_create_person
    person = Persons.create_person('Foo bar')
    assert_equal 'bfoo', person.login_name

    person = Persons.create_person('Foo bar', @secretary)
    assert_equal 'bfoo2', person.login_name

    person = Persons.create_person('Foo bar', @secretary, 'foobar')
    assert_equal 'foobar', person.login_name

    person = Persons.create_person('Foo bar', @center)
    assert_equal 'foo_bfoo', person.login_name

    person = Persons.create_person('Foo bar', @center, 'foobar')
    assert_equal 'foo_foobar', person.login_name

  end

  def test_responsibles_raw
    resps = Persons.responsibles_raw
    assert_equal %w(josue secr teacher foo),
                 resps.collect { |p| p.login_name }
  end

  def test_migrate_5
    #dp ''
    Entities.delete_all_data()
    ACQooxView.check_db
    #dp Accounts.search_by_name('Lending')
    lending = Accounts.create('Linus', 'Too lazy', Accounts.match_by_name('Lending'))
    paid = Accounts.create('Paid', '', lending)
    cash = Accounts.create('Linus', 'Too lazy', Accounts.match_by_name('Cash'))
    ConfigBases.init

    FileUtils.mkdir_p 'data2'
    IO.write 'data2/Persons.csv',
             '{"person_id":2,"login_name":"linus","permissions":["teacher"],'+
                 '"first_name":"Linus","family_name":"","internet_credit":0,'+
                 '"password_plain":"6978","password":"6978","gender":["male"],'+
                 '"account_name_due":"Linus","account_name_cash":"Linus"}' +
                 "\n"
    IO.write 'data2/MigrationVersions.csv',
             '{"migrationversion_id":1,"class_name":"Person","version":4}' +
                 "\n"
    Entities.load_all

    linus = Persons.match_by_login_name :linus
    assert_equal lending, linus.account_due
    assert_equal paid, linus.account_due_paid
    assert_equal cash, linus.account_cash
  end

  def test_double_responsibles
    assert_equal %w(josue secr teacher foo),
                 Persons.responsibles_raw.collect { |p| p.login_name }
  end

  def test_delete_responsible
    @teacher.delete
    assert_equal %w(josue secr foo),
                 Persons.responsibles_raw.collect { |p| p.login_name }
    assert_equal %w(Foo Josue Secr),
                 Persons.responsibles.collect { |i, n| n }
  end

  def test_search_in
    lvl = 3
    assert_equal [], Persons.search_in('foobar')
    assert_equal 2, Persons.search_in('student').length
    assert_equal 0, Persons.search_in('test_search').length
    assert_equal 0, Persons.search_in('test').length
    assert_equal 0, Persons.search_in('search').length

    (1..400).each { |i|
      Persons.create(login_name: "test_search_#{i}", first_name: 'test',
                     family_name: 'search')
    }

    Timing.measure(lvl) { assert_equal 20, Persons.search_in('test_search').length }
    Timing.measure(lvl) { assert_equal 20, Persons.search_in('test').length }
    Timing.measure(lvl) { assert_equal 20, Persons.search_in('search').length }

    Timing.measure(lvl) { assert_equal 400, Persons.search_in('test_search', max: 400).length }
  end
end
