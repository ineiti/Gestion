require 'test/unit'

Permission.add( 'default', '.*' )
Permission.add( 'student', '.*' )
Permission.add( 'teacher', '.*' )

class TC_QVInfo < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
    @admin = Entities.Persons.create( :login_name => "admin", :password => "super123", 
    :permissions => [ "default", "teacher" ], :first_name => "Admin", :family_name => "The" )
    @secretaire = Entities.Persons.create( :login_name => "josue", :password => "super", 
    :permissions => [ "default", "teacher" ], :first_name => "Le", :family_name => "Secretaire" )
    @surf = Entities.Persons.create( :login_name => "surf", :password => "super", 
    :permissions => [ "default" ], :first_name => "Internet", :family_name => "Surfer" )
    @net = Entities.Courses.create( :name => "net_1001", :start => "01.02.03", :end => "04.05.03" )
    @base = Entities.Courses.create( :name => "base_1004" )
    @base.students = %w( admin2 surf )
  end
  
  def test_course
    # Is the student allowed to log-in during the duration of the course?
  end
  
  def test_internet
    # Can the person connect to the internet if he has cash?
  end
end