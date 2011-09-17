require 'test/unit'

Permission.add( 'default', '.*' )
Permission.add( 'student', '.*' )
Permission.add( 'teacher', '.*' )

class TC_Person < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
    @admin = Entities.Persons.create( :login_name => "admin", :password => "super123", 
    :permissions => [ "default", "teacher" ], :first_name => "Admin", :family_name => "The" )
    @secretaire = Entities.Persons.create( :login_name => "josue", :password => "super", 
    :permissions => [ "default", "teacher" ], :first_name => "Le", :family_name => "Secretaire" )
    @surf = Entities.Persons.create( :login_name => "surf", :password => "super", 
    :permissions => [ "default" ], :first_name => "Internet", :family_name => "Surfer" )
    @net = Entities.Courses.create( :name => "net_1001" )
    @base = Entities.Courses.create( :name => "base_1004" )
    @base.students = %w( admin2 surf )
  end
  
  def teardown
    #Entities.Persons.save
    #Entities.LogActions.save
  end
  
  def tes_bulk
    names = [ "Dmin A","Zero","One Two","Ten Eleven Twelve","A B C D",
    "Hélène Méyère","Äeri Soustroup" ]
    while names.length > 0
      reply = RPCQooxdooHandler.request( 1, "View.CourseModify", "button", [["default", "bulk_students",
      {"name" => "net_1001", "names" => names.join("\n") }]])
      assert_not_nil reply
      names.shift
    end
    bulk = [ [ "zero", "Zero", "" ], %w( tone One Two ), [ "eten", "Ten", "Eleven Twelve" ],
    ["ca_b", "A B", "C D"], %w( admin2 Dmin A ), %w( mhelene Hélène Méyère ) ]
    bulk.each{|b|
      login, first, family = b
      dputs 0, "Doing #{b.inspect}"
      p = Entities.Persons.find_by_login_name( login )
      assert_not_nil p, login.inspect
      assert_equal login, p.login_name
      assert_equal first, p.first_name
      assert_equal family, p.family_name
      assert_equal %w( student ), p.permissions
    }
    
    students = Entities.Courses.find_by_name( 'net_1001' ).students
    assert_equal %w( admin2 ca_b eten mhelene s_eri tone zero ), students.sort
  end
  
  def tes_grade
    @grade0 = Entities.Grades.save_data({:person_id => @secretaire.person_id,
    :course_id => @net.course_id, :mean => 11})
    assert_equal 11, @grade0[:mean]
    @grade1 = Entities.Grades.save_data({:person_id => @surf.person_id,
    :course_id => @net.course_id, :mean => 12})
    assert_equal 12, @grade1[:mean]
    @grade2 = Entities.Grades.save_data({:person_id => @surf.person_id,
    :course_id => @net.course_id, :mean => 13})
    assert_equal 13, @grade2[:mean]
    assert_equal @grade1[:grade_id], @grade2[:grade_id]
  end
  
  def tes_search
    reply = RPCQooxdooHandler.request( 1, "View.CourseModify", "button", [["default", "bulk_students",
    {"name" => "net_1001", "names" => "Dmin A" }]])
    courses_admin2 = Entities.Courses.search_by_students( "admin2" )
    courses_surf = Entities.Courses.search_by_students( "surf" )
    assert_equal 2, courses_admin2.length
    assert_equal 1, courses_surf.length
  end
  
  COURSE_STR = "base_gestion\nAdmin The\nLe Secretaire\n72\nCours de base\nWord\nExcel\nLinux\n\n"+
      "1er février 03\n4 mai 03\n4 juin 03\n" +
      "P Admin The\n\nNP Internet Surfer\nhttp://ndjair.net\n" 
  
  # Check different assertions of missing stuff and students
  def tes_diploma_export
    assert_equal %w( start end sign duration teacher responsible description contents ), 
    @net.export_check
    
    @net.start = "01.02.03"
    @net.end = "04.05.03"
    @net.sign = "04.06.03"
    @net.duration = 72
    @net.teacher = "admin"
    @net.responsible = "josue"
    @net.description = "Cours de base"
    @net.contents = "Word\nExcel\nLinux"
    
    assert_nil @net.export_check
    
    assert_equal "base_gestion\n1er février 03\n4 mai 03\n4 juin 03\n\n72\nAdmin The" +
    "\nLe Secretaire\nCours de base\nWord\nExcel\nLinux\n", 
    @net.export_diploma
    
    @net.students = %w( admin surf )
    
    Entities.Grades.save_data({:person_id => @admin.person_id,
    :course_id => @net.course_id, :mean => 11})
    Entities.Grades.save_data({:person_id => @surf.person_id,
    :course_id => @net.course_id, :mean => 9, :remark => "http://ndjair.net"})
    
    assert_equal COURSE_STR, @net.export_diploma
  end
  
  def test_diploma_import
    course = Courses.from_diploma( "net_1001", COURSE_STR )
    @grade_admin = Entities.Grades.find_by_course_person( @net.course_id, @admin.login_name )
    assert_not_nil @grade_admin
    assert_equal 10, @grade_admin.mean
    assert_equal %w( 01.02.2003 04.05.2003 04.06.2003 72 admin josue ),
      course.data_get( %w( start end sign duration teacher responsible ) )
  end
end
