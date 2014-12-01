require 'test/unit'


class TC_Configbase < Test::Unit::TestCase
  def setup
  end
  
  def teardown
  end
  
  def test_migration
    assert_fail 'Write other test as libnet_uri is not here anymore'
    Entities.delete_all_data
    ConfigBases.create( :functions => [] )
    set_config( false, :LibNet, :simulation )
    set_config( "internet:3301", :LibNet, :URI )
    Entities.load_all
    RPCQooxdooService.migrate_all
  end
end
