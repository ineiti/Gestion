require 'test/unit'
require 'network'
include Network

class LibNet
  def initialize
    $connection_status = 0
    $users_connected = []
  end

  def call(f, *r)
    dputs(3){"Calling #{f.inspect} with #{r.inspect}"}
    case f
    when :isp_connection_status
      return $connection_status
    when :users_connected
      return $users_connected.join("\n")
    when :user_cost_now
      if $users_connected.count > 0
        return 5 + 10 / $users_connected.count
      else
        return 15
      end
    when :isp_params
      return isp_params
    when :user_connect
      $users_connected.push(r[0].split()[1])
    when :user_disconnect
      $users_connected.delete(r[0].split()[1])
    when :user_disconnect_name
      $users_connected.delete(r[0])
    when :users_disconnected
      ""
    end
  end

  def isp_params
    dputs(3) { "Returning #{$libnet_isp.to_json}" }
    $libnet_isp
  end

  def print(v)
    case v
    when :USAGE_DAILY
      return 10.0
    else
      dputs(1) { "Undefined value #{v.inspect}" }
    end
  end

  def call_to_be_replaced_args(f, *a)
    ip, name = a[0].split()
    dputs(2) { "users is #{$users_connected.inspect} and function " +
        "is #{f} with args #{a.inspect}" }
    case f
    when :user_connect
      $users_connected.push(name)
    when :user_disconnect
      $users_connected.delete(name)
    when :user_disconnect_name
      $users_connected.delete(ip)
    end
    dputs(2) { "users_connected is #{$users_connected.inspect}" }
  end
end

class Web_req
  attr_reader :peeraddr, :header

  def initialize(ip)
    @peeraddr = [0, 0, 0, ip]
  end
end

class TC_Internet < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
    @test = Persons.create(:login_name => "test", :internet_credit => 50)
    Sessions.create(@test).web_req = Web_req.new(10)
    @test2 = Persons.create(:login_name => "test2", :internet_credit => 50)
    @free = Persons.create(:login_name => "free", :internet_credit => 50,
      :groups => ['freesurf'])
    dputs(1) { "#{@test.inspect}" }
    ConfigBase.captive_dev = 'simul0'
    ConfigBase.cost_base = 10
    ConfigBase.cost_shared = 10
    ConfigBase.send_config
    Internet.setup
    @device = Device::Simulation.load
    @operator = @device.operator
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

    assert_equal 50, @test.internet_credit

    Internet.take_money
    assert_equal 50, @test.internet_credit

    $connection_status = 5

    Captive.user_connect( 10, :test )
    Internet.take_money
    assert_equal 35, @test.internet_credit

    Captive.user_connect( 11, :test2 )
    Internet.take_money
    assert_equal 25, @test.internet_credit
    assert_equal 40, @test2.internet_credit

    Captive.user_connect( 12, :free )
    Internet.take_money
    assert_equal 17, @test.internet_credit
    assert_equal 32, @test2.internet_credit
    assert_equal 42, @free.internet_credit

    Captive.user_disconnect( 12, :free )
    Captive.user_disconnect( 11, :test2 )
    Internet.take_money
    assert_equal 2, @test.internet_credit
    Internet.take_money
    assert_equal [], $users_connected
  end


  def test_take_money_perm
    libnet_isp_vsat

    assert_equal 50, @test.internet_credit

    Internet.take_money
    assert_equal 50, @test.internet_credit

    $connection_status = 5

    Captive.user_connect 10, :test
    Internet.take_money
    assert_equal 35, @test.internet_credit

    Captive.user_connect 11, :test2
    Internet.take_money
    assert_equal 25, @test.internet_credit
    assert_equal 40, @test2.internet_credit

    assert_equal 50, @free.internet_credit
    Captive.user_connect 12, :free
    Internet.take_money
    assert_equal 17, @test.internet_credit
    assert_equal 32, @test2.internet_credit
    assert_equal 50, @free.internet_credit

    Captive.user_disconnect 12, :free
    Captive.user_disconnect 11, :test2
    Internet.take_money
    assert_equal 2, @test.internet_credit
    Internet.take_money
    assert_equal [], $users_connected
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

end
