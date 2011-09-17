require 'test/unit'

class TC_Login < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
    Entities.Persons.create( :full_name => "admin", :password => "super123", :permissions => [ "admin" ] )
    Entities.Persons.create( :full_name => "josue", :password => "super", :permissions => [ "secretary" ] )
    Entities.Persons.create( :full_name => "surf", :password => "super", :permissions => [ "internet" ] )
  end
  
  def teardown
  end
  
  def test_login
    admin = Entities.Persons.find_by_login_name( "admin" )
    assert_not_nil admin, "Couldn't get 'admin'"
    
    reply = RPCQooxdooHandler.request( 1, "View.Welcome", "button", [["default", "login",
    {"username" => "admin", "password" => "super123" }]])
    assert_not_nil reply
    assert_not_equal nil, reply['result'].index{|i| i[:cmd] == "session_id"}, "#{reply.inspect}"
    
    reply = RPCQooxdooHandler.request( 1, "View.Welcome", "button", [["default", "login",
    {"username" => "josue", "password" => "false" }]])
    assert_not_nil reply
    assert_equal [], reply['result'], "#{reply.inspect}"
    
    reply = RPCQooxdooHandler.request( 1, "View.Welcome", "button", [["default", "login",
    {"username" => "foo", "password" => "false" }]])
    assert_not_nil reply
    assert_equal [], reply['result'], "#{reply.inspect}"
  end
  
end
