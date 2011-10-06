class TC_Tasks < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
    @pers_admin = Entities.Persons.create( :first_name => "admin", :password => "super123", 
    :permissions => [ "default" ] )
    @client_one = Entities.Clients.create( :name => "one" )
    @worker_foo = Entities.Workers.create( :person_id => @pers_admin.person_id,
      :login_name => @pers_admin.login_name )
    @task_one = Entities.Tasks.create( :client => @client_one.name, 
      :person => @pers_admin.login_name, :date => "11.03.2011", :time => "11:00" )
  end

  def teardown
  end

  def test_addlogin
  end

end
