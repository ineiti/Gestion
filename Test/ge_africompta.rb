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
		@cash = Entities.Accounts.find_by_name( "Cash" )
		@income = Entities.Accounts.find_by_name( "Income" )
		@outcome = Entities.Accounts.find_by_name( "Outcome" )
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
		
		assert_equal [{:movement_id=>1,
				:value=>1000.0,
				:desc=>"Salary",
				:revision=>nil,
				:account_src_id=>[2],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-1",
				:index=>1,
				:account_dst_id=>[3]},
			{:movement_id=>2,
				:value=>100.0,
				:desc=>"Gift",
				:revision=>nil,
				:account_src_id=>[2],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-2",
				:index=>2,
				:account_dst_id=>[3]},
			{:movement_id=>3,
				:value=>40.0,
				:desc=>"Train",
				:revision=>nil,
				:account_src_id=>[4],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-3",
				:index=>3,
				:account_dst_id=>[2]},
			{:movement_id=>4,
				:value=>20.0,
				:desc=>"Restaurant",
				:revision=>nil,
				:account_src_id=>[4],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-4",
				:index=>4,
				:account_dst_id=>[2]}], 
			movs.collect{ |m| 
			m.to_hash.delete_if{|k,v| k == :date
			} }
			
		assert_equal [{:account_id=>1,
				:multiplier=>1.0,
				:total=>"0",
				:desc=>"Full description",
				:parent_id=>0,
				:name=>"Root",
				:global_id=>"5544436cf81115c6faf577a7e2307e92-1",
				:index=>1},
			{:account_id=>2,
				:multiplier=>-1.0,
				:total=>"1040.0",
				:desc=>"Full description",
				:parent_id=>[1],
				:name=>"Cash",
				:global_id=>"5544436cf81115c6faf577a7e2307e92-2",
				:index=>5},
			{:account_id=>3,
				:multiplier=>1.0,
				:total=>"1100.0",
				:desc=>"Full description",
				:parent_id=>[1],
				:name=>"Income",
				:global_id=>"5544436cf81115c6faf577a7e2307e92-3",
				:index=>3},
			{:account_id=>4,
				:multiplier=>1.0,
				:total=>"-60.0",
				:desc=>"Full description",
				:parent_id=>[1],
				:name=>"Outcome",
				:global_id=>"5544436cf81115c6faf577a7e2307e92-4",
				:index=>4}], 
			accs.collect{|a| a.to_hash}
		
		assert_equal [{:full=>"5544436cf81115c6faf577a7e2307e92",
				:pass=>"152020265102732202950475079275867584513",
				:account_index=>6,
				:movement_index=>5,
				:name=>"local",
				:user_id=>1}],
			users.collect{|u| u.to_hash}
  end
	
	def test_mov
		# Test all methods copied into Movements
		mov = Entities.Movements.find_by_desc( "Train" )
		
		assert_equal 40, mov.value
		assert_equal "Train\r5544436cf81115c6faf577a7e2307e92-3\t40.0\t2012-07-02\t" + 
			"5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2", 
			mov.to_s
		assert_equal "\"Train\\r5544436cf81115c6faf577a7e2307e92-3\\t40.0\\t" +
			"2012-07-02\\t5544436cf81115c6faf577a7e2307e92-4\\t" + 
			"5544436cf81115c6faf577a7e2307e92-2\"", 
			mov.to_json
		assert_equal( {:global_id=>"5544436cf81115c6faf577a7e2307e92-2",
				:desc=>"Full description",
				:total=>"1040.0",
				:multiplier=>-1.0,
				:account_id=>1,
				:name=>"Cash",
				:id=>2,
				:index=>5}, 
			mov.get_other_account( mov.account_src ).to_hash )
		
		# This is 11th of July 2012
		assert_equal "1040.0", @cash.total

		mov.set( "new", "11/7/12", 120, @cash, @income )
		assert_equal "new\r5544436cf81115c6faf577a7e2307e92-3\t120\t2012-07-11\t" + 
			"5544436cf81115c6faf577a7e2307e92-2\t5544436cf81115c6faf577a7e2307e92-3", 
			mov.to_s
		assert_equal 1200, @cash.total
		
		assert_equal 120.0, mov.get_value( @cash )
		
		assert_equal true, mov.is_in_account( @cash )
		assert_equal false, mov.is_in_account( @outcome )
		
		assert_equal 5, mov.get_index
	end
	
	def test_movs
		assert_equal "1040.0", @cash.total
		assert_equal "-60.0", @outcome.total
		
		# Overwriting movement with id 4: Restaurant with value = 20.0
		mov = Movements.from_s "Restaurant\r5544436cf81115c6faf577a7e2307e92-4\t10" + 
			"\t2012-07-12\t" + 
			"5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2"
		assert_equal( 1050.0, @cash.total )
		assert_equal( -50.0, @outcome.total )
		assert_equal( 10.0, mov.value )
		
		# Creating new movement
		newmov = Movements.from_s "Car\r5544436cf81115c6faf577a7e2307e92-5\t100" + 
			"\t2012-07-12\t" +
			"5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2"
		assert_equal 950.0, @cash.total
		assert_equal( -150.0, @outcome.total )
		assert_equal( 100.0, newmov.value )
		
		# Testing JSON
		mov_json = newmov.to_json
		assert_equal "{\"str\":\"Car\\r5544436cf81115c6faf577a7e2307e92-5\\t100.0\\t" + 
			"12/7/2012\\t5544436cf81115c6faf577a7e2307e92-4\\t" + 
			"5544436cf81115c6faf577a7e2307e92-2\"}", 
			mov_json
		newmov.value = 50
		assert_equal( 1000.0, @cash.total )
		newmov = Movements.from_json mov_json
		assert_equal( 950.0, @cash.total )
		assert_equal( 100.0, newmov.value )
	end
	
	def test_account
		
	end

end
