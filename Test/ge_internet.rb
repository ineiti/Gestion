require 'test/unit'
require 'network'
include Network

class Web_req
  attr_reader :peeraddr, :header

  def initialize(ip)
    @peeraddr = [0, 0, 0, ip]
  end
end

class TC_Internet < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
    ConfigBase.store(functions:[:internet_captive])
    @test = Persons.create(:login_name => 'test', :internet_credit => 50)
    Sessions.create(@test).web_req = Web_req.new(10)
    @test2 = Persons.create(:login_name => 'test2', :internet_credit => 50)
    @free = Persons.create(:login_name => 'free', :internet_credit => 50,
      :groups => ['freesurf'])
    dputs(1) { "#{@test.inspect}" }
    @device = Device::Simulation.load
    @operator = @device.operator

    ConfigBase.captive_dev = 'simul0'
    ConfigBase.cost_base = 5
    ConfigBase.cost_shared = 10
    ConfigBase.send_config
    Captive.cleanup_skip = true
    Internet.setup
  end

  def teardown
  end

  def libnet_isp_gprs
    @operator.connection_type = Operator::CONNECTION_ONDEMAND
    Operator.allow_free = false
  end

  def libnet_isp_vsat
    @operator.connection_type = Operator::CONNECTION_ALWAYS
    Operator.allow_free = true
  end

  def test_take_money
    libnet_isp_gprs

    @device.connection_status = Device::DISCONNECTED

    assert_equal 50, @test.internet_credit

    Internet.take_money
    assert_equal 50, @test.internet_credit

    @device.connection_status = Device::CONNECTED

    Captive.user_connect :test, 10
    Internet.take_money
    assert_equal 35, @test.internet_credit

    Captive.user_connect :test2, 11
    Internet.take_money
    assert_equal 25, @test.internet_credit
    assert_equal 40, @test2.internet_credit

    Captive.user_connect :free, 12
    Internet.take_money
    assert_equal 17, @test.internet_credit
    assert_equal 32, @test2.internet_credit
    assert_equal 50, @free.internet_credit

    Captive.user_disconnect( :free, 12 )
    Captive.user_disconnect( :test2, 11 )
    Internet.take_money
    assert_equal 2, @test.internet_credit
    Internet.take_money
    assert_equal [], Captive.users_connected
  end


  def test_take_money_perm
    libnet_isp_vsat

    assert_equal 50, @test.internet_credit

    Internet.take_money
    assert_equal 50, @test.internet_credit

    @device.connection_status = Device::CONNECTED

    Captive.user_connect :test, 10
    Internet.take_money
    assert_equal 35, @test.internet_credit

    Captive.user_connect :test2, 11
    Internet.take_money
    assert_equal 25, @test.internet_credit
    assert_equal 40, @test2.internet_credit

    assert_equal 50, @free.internet_credit
    Captive.user_connect :free, 12
    Internet.take_money
    assert_equal 17, @test.internet_credit
    assert_equal 32, @test2.internet_credit
    assert_equal 50, @free.internet_credit

    Captive.user_disconnect :free, 12
    Captive.user_disconnect :test2, 11
    Internet.take_money
    assert_equal 2, @test.internet_credit
    Internet.take_money
    assert_equal [], Captive.users_connected
  end

  def test_users_str
    assert_equal "one, three, two",
      SelfInternet.make_users_str(%w( one two three).join("\n"))

    assert_equal "four, one, three, two",
      SelfInternet.make_users_str(%w( one two three four ).join("\n"))

    assert_equal "five, four, one, six,<br>three, two",
      SelfInternet.make_users_str(%w( one two three four five six ).join("\n"))
  end

  def test_atimes
    ag1 = AccessGroups.create(:name => "office", :members => %w( test free ),
      :action => %w( allow_else_block ), :priority => 20, :limit_day_mo => 200,
      :access_times => %w( lu-ve;08:00;10:00 lu-ve;10:30;13:00 lu-ve;16:00;18:00 ))
    assert_equal false,
      AccessGroup.time_in_atime(Time.parse("2012/1/1 10:00"), "lu-ve;8:00;12:00")
    assert_equal true,
      AccessGroup.time_in_atime(Time.parse("2012/1/2 10:00"), "lu-ve;8:00;12:00")
    assert_equal true,
      AccessGroup.time_in_atime(Time.parse("2012/1/2 10:00"), "lu,ma;8:00;12:00")
    assert_equal false,
      AccessGroup.time_in_atime(Time.parse("2012/1/2 10:00"), "me;8:00;12:00")
    assert_equal true,
      AccessGroup.time_in_atime(Time.parse("2012/1/2 10:00"), "lu-di;8:00;12:00")
    assert_equal true,
      AccessGroup.time_in_atime(Time.parse("2012/1/3 4:00"), "lu;22:00;6:00")
    assert_equal false,
      AccessGroup.time_in_atime(Time.parse("2012/1/3 6:00"), "lu;22:00;6:00")

    assert_equal false,
      ag1.time_in_atimes(Time.parse("2012/1/1 8:0"))
    assert_equal true,
      ag1.time_in_atimes(Time.parse("2012/1/2 8:0"))
  end

  def test_access_groups
    ag1 = AccessGroups.create(:name => "office", :members => %w( test free ),
      :action => %w( allow_else_block ), :priority => 20, :limit_day_mo => 200,
      :access_times => %w( lu-ve;08:00;10:00 lu-ve;10:30;13:00 lu-ve;16:00;18:00 ))

    assert_equal [true, 'office'], AccessGroups.allow_user("test",
      Time.parse("1/2/2012 8:0"))
    assert_equal [true, 'default'], AccessGroups.allow_user("test2",
      Time.parse("1/2/2012 8:0"))

    assert_equal [true, 'default'], AccessGroups.allow_user("test2",
      Time.parse("1/2/2012 10:0"))
    ag2 = AccessGroups.create(:name => "block", :members => %w(  ),
      :action => %w( block ), :priority => 30, :limit_day_mo => 200,
      :access_times => %w( lu,ma,me,je,ve,sa,di;8:0;10:30 ))
    assert_equal [false, 'Blocked by rule **block**'], AccessGroups.allow_user("test2",
      Time.parse("1/2/2012 10:0"))
    assert_equal [false, 'Blocked by rule **block**'], AccessGroups.allow_user("test",
      Time.parse("1/2/2012 8:0"))
    ag2.priority = 10
    assert_equal [true, 'office'], AccessGroups.allow_user("test",
      Time.parse("1/2/2012 8:0"))

    assert_equal [false, 'Blocked by rule **block**'], AccessGroups.allow_user("test2",
      Time.parse("1/2/2012 10:0"))
    ag3 = AccessGroups.create(:name => "director", :members => %w( test2 ),
      :action => %w( allow ), :priority => 40, :limit_day_mo => 200,
      :access_times => %w( lu-di;8:0;10:30 ))
    assert_equal [true, 'director'], AccessGroups.allow_user("test2",
      Time.parse("1/2/2012 10:0"))
    assert_equal [true, 'director'], AccessGroups.allow_user("test2",
      Time.parse("1/3/2012 10:0"))

    ag2.priority = 30
    assert_equal [false, 'Blocked by rule **block**'], AccessGroups.allow_user("test",
      Time.parse("1/2/2012 8:0"))
    ag4 = AccessGroups.create(:name => "everybody", :members => %w( test ),
      :action => %w( allow ), :priority => 60, :limit_day_mo => 200)
    assert_equal [true, 'everybody'], AccessGroups.allow_user("test",
      Time.parse("1/2/2012 8:0"))

  end

  def test_header
    #assert_fail "Shall test for ip-address in header"
  end

  def test_active_course
    user_1 = Persons.create( login_name: 'user1' )
    user_2 = Persons.create( login_name: 'user1' )
    course = Courses.create( name: 'internet', students: [user_1.login_name, user_2.login_name])

    assert_equal false, Internet.active_course_for( user_1 )
    assert_equal false, Internet.active_course_for( user_2 )

    course.start = Date.yesterday.strftime('%d.%m.%Y')
    course.end = Date.tomorrow.strftime('%d.%m.%Y')

    assert_equal true, Internet.active_course_for( user_1 )
    assert_equal true, Internet.active_course_for( user_2 )
  end

  def test_internet_person
    ic_inf = InternetClasses.create(name: 'unlimited', type: ['unlimited'])
    ic_lim = InternetClasses.create(name: 'daily', type: ['limit_daily_mo'])
    ip = InternetPersons.create(person:@test, iclass: ic_inf)
    t = Date.today
    tr = Internet.traffic

    assert ip.is_active?
    ip.start = (t - 10).to_web
    assert ip.is_active?
    ip.duration = 1
    assert !ip.is_active?
    ip.duration = 10
    assert ip.is_active?

    tr.traffic_init(:test, [0,0])
    assert_equal 0, tr.get_day(:test, 1).first.inject(:+)
    assert ic_inf.in_limits?(:test)
    assert !ic_lim.in_limits?(:test)
    ic_lim.limit = 1
    assert ic_lim.in_limits?(:test)

    ip.iclass = ic_lim
    assert ip.in_limits?
    tr.update_host(:test, [500_000, 500_000])
    assert !ip.in_limits?
  end

end
