require 'test/unit'

class TC_View < Test::Unit::TestCase
  
  def setup
    Entities.delete_all_data()
  end
  
  def teardown
    
  end
  
  def test_openprint
    mm = PersonModify.new
    
    assert_equal %w( PDF HP_LaserJet ), mm.get_printers
    
    assert_equal mm.reply(:update, :print_student => "print_student PDF"), 
      mm.reply_print( nil )
    
    assert_equal mm.reply(:update, :print_student => "print_student HP_LaserJet"), 
      mm.rpc_print( nil, :print_student, 'menu' => "HP_LaserJet" )
    
    assert_equal mm.reply(:update, :print_student => "print_student HP_LaserJet"), 
      mm.rpc_print( nil, :print_student, {} )
    
    assert_equal mm.reply(:update, :print_student => "print_student HP_LaserJet"), 
      mm.rpc_print( nil, :print_student, 'menu' => "" )
    
    assert_equal "HP_LaserJet", mm.get_printer( :print_student )
  end

end