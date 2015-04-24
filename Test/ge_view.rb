require 'test/unit'

class TC_View < Test::Unit::TestCase

  def setup
    Entities.delete_all_data()
    @admin = Entities.Persons.create(:login_name => 'admin', :password => 'super123',
                                     :permissions => ['default'])
    @foo = Entities.Persons.create(:login_name => 'foo', :password => 'bar',
                                     :permissions => %w(default internet admin))
  end

  def teardown

  end

  def get_reply(service, method, session, arguments = [])
    #dp RPCQooxdooService::services
    s = RPCQooxdooService::services["View.#{service}"]
    m = "rpc_#{method}"
    parsed = s.parse_request(m, session, arguments)
    s.parse_reply(m, session, parsed)
  end

  def test_speed_login
    Struct.new('Webreq', :header, :peeraddr)
    (1..200).each { |i|
      Timing.measure("Measure #{i}", 3) {
        session = Sessions.create
        session.web_req = Struct::Webreq.new({host: 'nil'}, [0, 0, 0, '192.168.1.1'])
        ret = get_reply(:Welcome, :button, session,
                        ['simple_connect', {'username' => 'foo', 'password' => 'bar'}])
        session = Sessions.match_by_sid(ret[0]._data)
        get_reply(:SelfTabs, :show, session, [])
        get_reply(:SelfTabs, :list_tabs, session, [])
        get_reply(:SelfInternet, :show, session, [])
        get_reply(:PersonTabs, :show, session)
        get_reply(:PersonTabs, :list_tabs, session)
        get_reply(:PersonModify, :show, session)
        if i % 10 == 0
          Entities.save_all
        end
      }
    }
  end
end