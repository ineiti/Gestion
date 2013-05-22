require 'test/unit'


class TC_Course < Test::Unit::TestCase
  def setup
  end
  
  def teardown
  end
  
  def test_usages
    View.AdminFunction.rpc_button_save( nil, {"usage" => [2,3] } )
    assert_equal %w( share courses ), View.AdminFunction.get_usages
  end
end
