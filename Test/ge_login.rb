require 'test/unit'

class SimulWebReq
  def self.header
    {}
  end
  
  def self.peeraddr
    [0,0,0,0]
  end
end

class TC_Login < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()

    dputs(1){"Resetting SQLite"}
    SQLite.dbs_close_all
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    SQLite.dbs_open_load_migrate

    Entities.Persons.create( :first_name => "admin", :password => "super123", :permissions => [ "admin" ] )
    Entities.Persons.create( :first_name => "josue", :password => "super", :permissions => [ "secretary" ] )
    Entities.Persons.create( :first_name => "surf", :password => "super", :permissions => [ "internet" ] )
  end

  def teardown
  end

  def test_login
    admin = Entities.Persons.match_by_login_name( "admin" )
    assert_not_nil admin, "Couldn't get 'admin'"

    reply = RPCQooxdooHandler.request( 1, "View.Welcome", "button", [["default", "login",
        {"username" => "admin", "password" => "super123" }]], SimulWebReq )
    assert_not_nil reply
    assert_not_equal nil, reply['result'].index{|i| i[:cmd] == :session_id}, reply.inspect

    reply = RPCQooxdooHandler.request( 1, "View.Welcome", "button", [["default", "login",
        {"username" => "josue", "password" => "false" }]])
    assert_not_nil reply
    assert_equal [{:data=>:login_failed, :cmd=>:window_show},
        {:data=>{:reason=>"Password wrong"}, :cmd=>:update}], reply['result'], "#{reply.inspect}"

    reply = RPCQooxdooHandler.request( 1, "View.Welcome", "button", [["default", "login",
        {"username" => "foo", "password" => "false" }]])
    assert_not_nil reply
    assert_equal [{:data=>:login_failed, :cmd=>:window_show},
        {:data=>{:reason=>"User doesn't exist"}, :cmd=>:update}], reply['result'], "#{reply.inspect}"
  end

end
