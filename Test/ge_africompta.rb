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
		@root = Entities.Accounts.find_by_name( "Root" )
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
		
		assert_equal [{:id=>1,
				:value=>1000.0,
				:desc=>"Salary",
				:revision=>nil,
				:account_src_id=>[2],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-1",
				:index=>1,
				:account_dst_id=>[3]},
			{:id=>2,
				:value=>100.0,
				:desc=>"Gift",
				:revision=>nil,
				:account_src_id=>[2],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-2",
				:index=>2,
				:account_dst_id=>[3]},
			{:id=>3,
				:value=>40.0,
				:desc=>"Train",
				:revision=>nil,
				:account_src_id=>[4],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-3",
				:index=>3,
				:account_dst_id=>[2]},
			{:id=>4,
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
			
		assert_equal [{:id=>1,
				:multiplier=>1.0,
				:total=>"0",
				:desc=>"Full description",
				:account_id=>0,
				:name=>"Root",
				:global_id=>"5544436cf81115c6faf577a7e2307e92-1",
				:index=>1},
			{:id=>2,
				:multiplier=>-1.0,
				:total=>"1040.0",
				:desc=>"Full description",
				:account_id=>[1],
				:name=>"Cash",
				:global_id=>"5544436cf81115c6faf577a7e2307e92-2",
				:index=>5},
			{:id=>3,
				:multiplier=>1.0,
				:total=>"1100.0",
				:desc=>"Full description",
				:account_id=>[1],
				:name=>"Income",
				:global_id=>"5544436cf81115c6faf577a7e2307e92-3",
				:index=>3},
			{:id=>4,
				:multiplier=>1.0,
				:total=>"-60.0",
				:desc=>"Full description",
				:account_id=>[1],
				:name=>"Outcome",
				:global_id=>"5544436cf81115c6faf577a7e2307e92-4",
				:index=>4}], 
			accs.collect{|a| a.to_hash}
		
		assert_equal [{:full=>"5544436cf81115c6faf577a7e2307e92",
				:pass=>"152020265102732202950475079275867584513",
				:account_index=>6,
				:movement_index=>5,
				:name=>"local",
				:id=>1}],
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
		tree = []
		@root.get_tree{|a| tree.push a.name }
		assert_equal "Root-Cash-Income-Outcome", tree.join("-")
		
		assert_equal "Root::Outcome", @outcome.path
		
		assert_equal 4, @outcome.index
		@outcome.new_index
		assert_equal 6, @outcome.index
		
		foo = Users.create( "foo", "foo bar", "foobar" )
		box = Accounts.create( "Cashbox", "Running cash", @cash, 
			"5544436cf81115c6faf577a7e2307e92-7")
		
		assert_equal "1040.0", @cash.total
		@cash.set_nochildmult( "Cash_2", "All money", @root, 1, [ foo.name ] )
		assert_equal "Cash_2", @cash.name
		assert_equal "All money", @cash.desc
		assert_equal 1, @cash.multiplier
		assert_equal( -1, box.multiplier )
		assert_equal "1040.0", @cash.total
		
		assert_equal([{:value=>20.0,
					:desc=>"Restaurant",
					:account_src_id=>[4],
					:revision=>nil,
					:account_dst_id=>[2],
					:global_id=>"5544436cf81115c6faf577a7e2307e92-4",
					:index=>4,
					:id=>4},
				{:value=>100.0,
					:desc=>"Gift",
					:account_src_id=>[2],
					:revision=>nil,
					:account_dst_id=>[3],
					:global_id=>"5544436cf81115c6faf577a7e2307e92-2",
					:index=>2,
					:id=>2},
				{:value=>40.0,
					:desc=>"Train",
					:account_src_id=>[4],
					:revision=>nil,
					:account_dst_id=>[2],
					:global_id=>"5544436cf81115c6faf577a7e2307e92-3",
					:index=>3,
					:id=>3},
				{:value=>1000.0,
					:desc=>"Salary",
					:account_src_id=>[2],
					:revision=>nil,
					:account_dst_id=>[3],
					:global_id=>"5544436cf81115c6faf577a7e2307e92-1",
					:index=>1,
					:id=>1}], 
			@cash.movements.collect{|m| m.to_hash.delete_if{|k,v| k == :date
				}} )
		
		assert_equal "All money\r5544436cf81115c6faf577a7e2307e92-2\t1040.0\t" + 
			"Cash_2\t1\t5544436cf81115c6faf577a7e2307e92-1", 
			@cash.to_s
		
		assert_equal false, @cash.is_empty
		box = Accounts.create( "Cashbox", "Running cash", @cash, 
			"5544436cf81115c6faf577a7e2307e92-8")
		assert_equal true, box.is_empty
		
		assert_equal( 1, @cash.multiplier )
		assert_equal( 1, box.multiplier )
		@cash.set_child_multipliers( -1 )
		assert_equal( -1, @cash.multiplier )
		assert_equal( -1, box.multiplier )
		
		assert_equal 6, Entities.Accounts.search_all.length
		box.delete
		assert_equal 5, Entities.Accounts.search_all.length
	end
	
	def test_accounts
		assert_equal 2, @cash.id
		
		box = Accounts.create( "Cashbox", "Running cash", @cash, 
			"5544436cf81115c6faf577a7e2307e92-8")
		assert_equal( {:multiplier=>-1,
				:desc=>"Running cash",
				:total=>"0",
				:account_id=>[2],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-8",
				:name=>"Cashbox",
				:id=>5,
				:index=>6}, box.to_hash )
		assert_equal "Root::Cash::Cashbox", box.path
		assert_equal( -1, @cash.multiplier )
		assert_equal( -1, box.multiplier )
		
		box_s = box.to_s
		box.delete
		box = Accounts.from_s( box_s )
		assert_equal( {:multiplier=>-1.0,
				:desc=>"Running cash",
				:total=>"0",
				:account_id=>[2],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-8",
				:name=>"Cashbox",
				:id=>5,
				:index=>8}, box.to_hash )
	end
	
	def test_users
		Users.create( "foo", "foo bar", "foobar" )
		foo = Users.find_by_name( "foo" )
		assert_equal "foo bar", foo.full
		assert_equal "foobar", foo.pass
	end

end
