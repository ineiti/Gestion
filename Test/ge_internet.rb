require 'test/unit'
require '../Internet'

class LibNet
  def initialize
    $connection_status = 0
    $users_connected = []
  end
	
  def call( f, r = nil )
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
      dputs(3){"Returning #{$libnet_isp.to_json}"}
      return $libnet_isp.to_json
    end
  end
	
  def call_args( f, *a )
    ip, name = a[0].split()
    dputs(2){"users is #{$users_connected.inspect} and function " + 
        "is #{f} with args #{a.inspect}"}
    case f
    when :user_connect
      $users_connected.push( name )
    when :user_disconnect
      $users_connected.delete( name )
    when :user_disconnect_name
      $users_connected.delete( ip )
    end
    dputs(2){"users_connected is #{$users_connected.inspect}"}
  end
end

class Web_req
  attr_reader :peeraddr
  def initialize(ip)
    @peeraddr = [ 0, 0, 0, ip ]
  end
end

class TC_Internet < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
    $lib_net = LibNet.new
    @test = Persons.create( :login_name => "test", :internet_credit => 50 )
    Sessions.create( @test ).web_req = Web_req.new( 10 )
    @test2 = Persons.create( :login_name => "test2", :internet_credit => 50 )
    @free = Persons.create( :login_name => "free", :internet_credit => 50, 
      :groups => ['freesurf'] )
    dputs(0){"#{@test.inspect}"}
  end
  
  def teardown
  end
  
  def libnet_isp_gprs
    $libnet_isp = {:conn_type => "ondemand" }
  end
  
  def libnet_isp_vsat
    $libnet_isp = {:conn_type => "permanent" }
  end
  
  def test_take_money
    libnet_isp_gprs
    
    assert_equal 50, @test.internet_credit

    Internet.take_money
    assert_equal 50, @test.internet_credit

    $connection_status = 5
	
    $lib_net.call_args( :user_connect, "10 test")
    Internet.take_money
    assert_equal 35, @test.internet_credit

    $lib_net.call_args( :user_connect, "11 test2")
    Internet.take_money
    assert_equal 25, @test.internet_credit
    assert_equal 40, @test2.internet_credit

    $lib_net.call_args( :user_connect, "12 free")
    Internet.take_money
    assert_equal 17, @test.internet_credit
    assert_equal 32, @test2.internet_credit
    assert_equal 42, @free.internet_credit

    $lib_net.call_args( :user_disconnect, "12 free")
    $lib_net.call_args( :user_disconnect, "11 test2")
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
	
    $lib_net.call_args( :user_connect, "10 test")
    Internet.take_money
    assert_equal 35, @test.internet_credit

    $lib_net.call_args( :user_connect, "11 test2")
    Internet.take_money
    assert_equal 25, @test.internet_credit
    assert_equal 40, @test2.internet_credit

    assert_equal 50, @free.internet_credit
    $lib_net.call_args( :user_connect, "12 free")
    Internet.take_money
    assert_equal 17, @test.internet_credit
    assert_equal 32, @test2.internet_credit
    assert_equal 50, @free.internet_credit

    $lib_net.call_args( :user_disconnect, "12 free")
    $lib_net.call_args( :user_disconnect, "11 test2")
    Internet.take_money
    assert_equal 2, @test.internet_credit
    Internet.take_money
    assert_equal [], $users_connected
  end
  
  def test_users_str
    assert_equal "one, three, two", 
      SelfInternet.make_users_str(%w( one two three) )

    assert_equal "four, one, three, two", 
      SelfInternet.make_users_str(%w( one two three four ) )

    assert_equal "five, four, one, six,<br>three, two", 
      SelfInternet.make_users_str(%w( one two three four five six ) )
  end
end
