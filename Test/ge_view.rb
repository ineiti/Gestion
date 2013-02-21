require 'test/unit'

class TC_View < Test::Unit::TestCase
  
  def setup
    Entities.delete_all_data()
    @admin = Entities.Persons.create( :login_name => "admin", :password => "super123",
      :permissions => [ "default" ] )
    @josue = Entities.Persons.create( :login_name => "josue", :password => "super",
      :permissions => [ "default" ] )

  end
  
  def teardown
    
  end
  
  def test_openprint
    mm = PersonModify.new
    sa = Sessions.create( @admin )
    sj = Sessions.create( @josue )
    PersonModify.class_eval("
      def call_lpstat(ip)
        return []
      end ")
    
    assert_equal [:print_student], mm.printer_buttons
    
    assert_equal mm.reply(:update, :print_student => "print_student PDF"), 
      mm.reply_print( sa )
    
    assert_equal mm.reply(:update, :print_student => "print_student HP_LaserJet"), 
      mm.rpc_print( sa, :print_student, 'menu' => "HP_LaserJet" )
    
    assert_equal mm.reply(:update, :print_student => "print_student HP_LaserJet"), 
      mm.rpc_print( sa, :print_student, {} )
    
    assert_equal mm.reply(:update, :print_student => "print_student HP_LaserJet"), 
      mm.rpc_print( sa, :print_student, 'menu' => "" )
    
    assert_equal "HP_LaserJet", mm.stat_printer( sa, :print_student ).data_str
    assert_equal "PDF", mm.stat_printer( sj, :print_student ).data_str

    assert_equal mm.reply(:update, :print_student => "print_student HP_LaserJet2"), 
      mm.rpc_print( sj, :print_student, 'menu' => "HP_LaserJet2" )    
    assert_equal "HP_LaserJet", mm.stat_printer( sa, :print_student ).data_str
    assert_equal "HP_LaserJet2", mm.stat_printer( sj, :print_student ).data_str
  end

end