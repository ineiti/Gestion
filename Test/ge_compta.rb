require 'test/unit'
require 'ftools'


class TC_Compta < Test::Unit::TestCase

  def setup
    #    Permission.add( 'default', '.*' )
    Permission.add( 'student', '.*' )
    Permission.add( 'teacher', '.*' )
#    Entities.delete_all_data()

    dputs(1){"Resetting SQLite"}
    SQLite.dbs_close_all
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    SQLite.dbs_open_load_migrate

    @admin = Entities.Persons.create( :login_name => "admin", :password => "super123", 
      :permissions => [ "default", "teacher" ], :first_name => "Admin", :family_name => "The" )
    @secretaire = Entities.Persons.create( :login_name => "secretaire", :password => "super", 
      :permissions => [ "default", "teacher" ], :first_name => "Le", :family_name => "Secretaire" )
    @surf = Entities.Persons.create( :login_name => "surf", :password => "super", 
      :permissions => [ "default" ], :first_name => "Internet", :family_name => "Surfer" )
    @net = Entities.Courses.create( :name => "net_1001" )
    @base = Entities.Courses.create( :name => "base_1004" )
    @maint = Entities.Courses.create( :name => "maint_1204", :start => "19.01.2012", :end => "18.02.2012",
      :dow => "lu-ve", :teacher => @secretaire )
    @maint.students = %w( admin surf )
    @base.students = %w( admin2 surf )
    @maint_t = Entities.CourseTypes.create( :name => "maint", :duration => 72,
      :desciption => "maintenance", :contents => "lots of work",
      :filename => ['base_gestion.odt'], :output => "certificate",
      :diploma_type => ["simple"])
    @maint_2 = Courses.create( :name => "maint_1210", :start => "1.10.2012",
      :end => "1.1.2013", :sign => "2.1.2012", :teacher => @secretaire,
      :contents => "lots of work", :description => "maintenance",
      :duration => 72, :responsible => @secretaire,
      :ctype => @maint_t )

    @it_101_t = CourseTypes.create( :name => "it-101", :diploma_type => ["accredited"], 
      :output => %w( label ), :filename => %w( label.odg ),
      :contents => "it-101", :description => "windows, word, excel",
      :central_host => "http://localhost:3302/label")
    @it_101 = Courses.create_ctype( @it_101_t, "1203" )
    @it_101.data_set_hash( :responsible => @secretaire, :teacher => @surf,
      :start => "1.11.2012", :end => "1.2.2013", :sign => "10.2.2013",
      :students => %w( secretaire surf ) )
    @center = Persons.create( :login_name => "foo", :permissions => ["center"],
      :address => "B.P. 1234", :town => "Sansibar",
      :phone => "+23599999999", :email => "profeda@gmail.com")
    @center.password = @center.password_plain = "1234"
    
    Sessions.create( @admin, "default" )
    
  end
  
  def teardown
    permissions_init
  end
  
  def test_link
    @account_foo = AccountLinks.get_account( "foo", "Root::Income::Foo" )
    assert_equal nil, @account_foo
  end
end
