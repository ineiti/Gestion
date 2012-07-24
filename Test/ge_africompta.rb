require 'test/unit'



class TC_AfriCompta < Test::Unit::TestCase
  def setup
		#    Entities.delete_all_data()
		#    Entities.Persons.create( :first_name => "admin", :password => "super123", :permissions => [ "admin" ] )
		#    Entities.Persons.create( :first_name => "josue", :password => "super", :permissions => [ "secretary" ] )
		#    Entities.Persons.create( :first_name => "surf", :password => "super", :permissions => [ "internet" ] )
		FileUtils.cp( "db.testGestion", "data/compta.db" )
		Entities.Movements.load
		Entities.Accounts.load
		Entities.Users.load
  end

  def teardown
  end

  def test_db
		movs = Entities.Movements.search_all
		assert_equal 4, movs.length
		accs = Entities.Accounts.search_all
		assert_equal 4, accs.length
		users = Entities.Users.search_all
		assert_equal 1, users.length
		
		assert_equal [{:value=>1000.0,
				:desc=>"Salary",
				:account_src_id=>2,
				:revision=>nil,
				:index=>1,
				:global_id=>"5544436cf81115c6faf577a7e2307e92-1",
				:id=>1,
				:account_dst_id=>3},
			{:value=>100.0,
				:desc=>"Gift",
				:account_src_id=>2,
				:revision=>nil,
				:index=>2,
				:global_id=>"5544436cf81115c6faf577a7e2307e92-2",
				:id=>2,
				:account_dst_id=>3},
			{:value=>40.0,
				:desc=>"Train",
				:account_src_id=>4,
				:revision=>nil,
				:index=>3,
				:global_id=>"5544436cf81115c6faf577a7e2307e92-3",
				:id=>3,
				:account_dst_id=>2},
			{:value=>20.0,
				:desc=>"Restaurant",
				:account_src_id=>4,
				:revision=>nil,
				:index=>4,
				:global_id=>"5544436cf81115c6faf577a7e2307e92-4",
				:id=>4,
				:account_dst_id=>2}], 
			movs.collect{ |m| 
			m.to_hash.delete_if{|k,v| k == :date
			} }
			
		assert_equal [{:account_id=>0,
				:total=>"0",
				:multiplier=>1.0,
				:desc=>"Full description",
				:name=>"Root",
				:index=>1,
				:global_id=>"5544436cf81115c6faf577a7e2307e92-1",
				:id=>1},
			{:account_id=>1,
				:total=>"1040.0",
				:multiplier=>-1.0,
				:desc=>"Full description",
				:name=>"Cash",
				:index=>5,
				:global_id=>"5544436cf81115c6faf577a7e2307e92-2",
				:id=>2},
			{:account_id=>1,
				:total=>"1100.0",
				:multiplier=>1.0,
				:desc=>"Full description",
				:name=>"Income",
				:index=>3,
				:global_id=>"5544436cf81115c6faf577a7e2307e92-3",
				:id=>3},
			{:account_id=>1,
				:total=>"-60.0",
				:multiplier=>1.0,
				:desc=>"Full description",
				:name=>"Outcome",
				:index=>4,
				:global_id=>"5544436cf81115c6faf577a7e2307e92-4",
				:id=>4}], 
			accs.collect{|a| a.to_hash}
		
		assert_equal [{:full=>"5544436cf81115c6faf577a7e2307e92",
				:pass=>"152020265102732202950475079275867584513",
				:account_index=>6,
				:movement_index=>5,
				:name=>"local",
				:id=>1}],
			users.collect{|u| u.to_hash}
  end

end
