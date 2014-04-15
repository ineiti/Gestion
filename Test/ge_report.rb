require 'test/unit'

class TC_Report < Test::Unit::TestCase

  def setup
    dp "hi"
    Entities.delete_all_data()

    dputs(1){"Resetting SQLite"}
    SQLite.dbs_close_all
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    SQLite.dbs_open_load_migrate

    @secretaire = Entities.Persons.create( :login_name => "secretaire", :password => "super", 
      :permissions => [ "default", "teacher" ], :first_name => "Le", :family_name => "Secretaire" )
    
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
  end
  
  def teardown
  end
  
  def test_report_list
    dp "hello"
    dp Accounts.dump( true )
  end
end
