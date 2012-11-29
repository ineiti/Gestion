require 'test/unit'
require '../Info.rb'
require '../Internet.rb'

class TC_info < Test::Unit::TestCase
  def setup
    @info = Info.new
    Entities.delete_all_data()
    Entities.Persons.create( :first_name => "admin", :password => "super123", :permissions => [ "admin" ], :groups => [] )
    Entities.Persons.create( :first_name => "josue", :password => "super", :permissions => [ "secretary" ] )
    Entities.Persons.create( :first_name => "surf", :password => "super", :permissions => [ "internet" ] )
  end

  def teardown
  end

  def test_clientuse
    dputs(0){ Info.clientUse({:user => "admin"}).to_s }
  end
end
