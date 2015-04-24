require 'test/unit'

class TC_sms < Test::Unit::TestCase
  def setup
  end

  def teardown
  end

  def test_last
    assert_equal [], SMSs.last( 0 )
    assert_equal [], SMSs.last( 2 )

    SMSs.create( { id: 1000,
                   phone: '12345678',
                   msg: 'This is a first SMS',
                   date: '2014-06-05 16:16:16'} )

    assert_equal 1, SMSs.last( 2 ).length

    SMSs.create( { id: 1001,
                   phone: '12345678',
                   msg: 'This is a first SMS',
                   date: '2014-06-05 16:16:17'} )

    SMSs.create( { id: 1002,
                   phone: '12345678',
                   msg: 'This is a first SMS',
                   date: '2014-06-05 16:16:18'} )

    assert_equal 2, SMSs.last( 2 ).length
    assert_equal( [1001, 1002], SMSs.last(2).collect{|s| s.index})
  end
end
