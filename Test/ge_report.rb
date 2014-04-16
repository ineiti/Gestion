require 'test/unit'

class TC_Report < Test::Unit::TestCase

  def setup
    Entities.delete_all_data()    

    SQLite.dbs_close_all
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    SQLite.dbs_open_load_migrate
    
    ConfigBase.add_function( :accounting_courses )

    @secretary = Entities.Persons.create( :login_name => "secretary", :password => "super", 
      :permissions => [ "default", "teacher", "secretary" ], 
      :first_name => "The", :family_name => "secretary" )
    
    @students = %w( Mahamat Younouss ).collect{|p|
      Persons.create( :login_name => p, :permissions => %w( student ) )
    }

    @maint_t = CourseTypes.create( :name => "maint", :duration => 72,
      :desciption => "maintenance", :contents => "lots of work",
      :filename => ['base_gestion.odt'], :output => "certificate",
      :diploma_type => ["simple"], 
      :account_base => Accounts.create_path("Root::Income::Courses"))

    @maint = Courses.create_ctype( @maint_t, "1404" )
    @maint.students = @students
    
    @root = Accounts.find_by_path( "Root")
    
    @report_simple = Reports.create( :name => "basic",
      :accounts => [
        ReportAccounts.create( :root => @root, :level => 1,
          :account => Accounts.find_by_path( "Root::Income")),
      ] )
    @report_double = Reports.create( :name => "basic",
      :accounts => [
        ReportAccounts.create( :root => @root, :level => 1,
          :account => Accounts.find_by_path( "Root::Income")),
        ReportAccounts.create( :root => @root, :level => 1,
          :account => Accounts.find_by_path( "Root::Lending"))
      ] )
  end
  
  def teardown
  end
  
  def test_report_list
    dp @secretary
    [[0,10000], [0, 5000], [1, 5000]].each{|s,c|
      @maint.payment( @secretary, @students[s], c )
    }
    #Accounts.dump( true )
    
    dp @report_simple.print_list
  end
end
