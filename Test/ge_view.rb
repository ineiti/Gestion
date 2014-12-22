require 'test/unit'

class TC_View < Test::Unit::TestCase
  
  def setup
    Entities.delete_all_data()
    @admin = Entities.Persons.create( :login_name => 'admin', :password => 'super123',
      :permissions => ['default'] )
    @josue = Entities.Persons.create( :login_name => 'josue', :password => 'super',
      :permissions => ['default'] )

  end
  
  def teardown
    
  end
end