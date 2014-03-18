require 'test/unit'


class TC_Configbase < Test::Unit::TestCase
  def setup
  end
  
  def teardown
  end
  
  def test_migration
    Entities.delete_all_data
    ConfigBases.create( :functions => [] )
    set_config( false, :LibNet, :simulation )
    set_config( "internet:3301", :LibNet, :URI )
    Entities.load_all
    RPCQooxdooService.migrate_all
    
    assert_equal( true, ConfigBase.has_function?( :internet_libnet ) )
    assert_equal "internet:3301", ConfigBase.libnet_uri
  end
end
