require 'test/unit'


class TC_Course < Test::Unit::TestCase
  def setup
    Permission.add( 'default', '.*' )
    Permission.add( 'student', '.*' )
    Permission.add( 'teacher', '.*' )
    Entities.delete_all_data()

    dputs(0){"Resetting SQLite"}
    SQLite.dbs_close_all
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    SQLite.dbs_open_load_migrate

    @admin = Entities.Persons.create( :login_name => "admin", :password => "super123", 
      :permissions => [ "default", "teacher" ], :first_name => "Admin", :family_name => "The" )
    @secretaire = Entities.Persons.create( :login_name => "josue", :password => "super", 
      :permissions => [ "default", "teacher" ], :first_name => "Le", :family_name => "Secretaire" )
    @surf = Entities.Persons.create( :login_name => "surf", :password => "super", 
      :permissions => [ "default" ], :first_name => "Internet", :family_name => "Surfer" )
    @net = Entities.Courses.create( :name => "net_1001" )
    @base = Entities.Courses.create( :name => "base_1004" )
    @maint = Entities.Courses.create( :name => "maint_1204", :start => "19.01.2012", :end => "18.02.2012",
      :teacher => @secretaire )
    @maint.students = %w( admin surf )
    @base.students = %w( admin2 surf )
    @maint_t = Entities.CourseTypes.create( :name => "maint", :duration => 72,
      :desciption => "maintenance", :contents => "lots of work",
      :filename => ['base_gestion.odt'])
    @maint_2 = Courses.create( :name => "maint_1210", :start => "1.10.2012",
      :end => "1.1.2013", :sign => "2.1.2012", :teacher => @secretaire,
      :contents => "lots of work", :description => "maintenance",
      :duration => 72, :responsible => @secretaire,
      :ctype => @maint_t )
    dputs(0){@maint_2.inspect}
  end
  
  def teardown
    permissions_init
    #Entities.Persons.save
    #Entities.LogActions.save
  end
  
  def test_bulk
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
      dputs( 0 ){ "Doing #{b.inspect}" }
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

  def test_grade
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

  def test_search
    courses_admin2 = Entities.Courses.search_by_students( "admin2" )
    assert_equal 1, courses_admin2.length
    reply = RPCQooxdooHandler.request( 1, "View.CourseModify", "button", [["default", "bulk_students",
          {"name" => "net_1001", "names" => "Dmin A" }]])
    courses_admin2 = Entities.Courses.search_by_students( "admin2" )
    courses_surf = Entities.Courses.search_by_students( "surf" )
    assert_equal 2, courses_admin2.length
    assert_equal 2, courses_surf.length
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
    @net.teacher = @admin
    @net.responsible = @secretaire
    @net.description = "Cours de base"
    @net.contents = "Word\nExcel\nLinux"
    
    assert_nil @net.export_check
    
    assert_equal "base_gestion\nAdmin The\nLe Secretaire\n72\nCours de base\nWord\nExcel\nLinux\n\n"+
      "1er février 03\n4 mai 03\n4 juin 03\n", 
      @net.export_diploma
    
    @net.students = %w( admin surf )
    
    Entities.Grades.save_data({:person_id => @admin.person_id,
        :course_id => @net.course_id, :mean => 11})
    Entities.Grades.save_data({:person_id => @surf.person_id,
        :course_id => @net.course_id, :mean => 9, :remark => "http://ndjair.net"})
    
    assert_equal COURSE_STR, @net.export_diploma
  end
  
  def notest_diploma_import
    # TODO:
    # As soon as value_entity are known to work OK, one has to replace
    # Course.teacher and Course.responsible with value_entity_person
    course = Courses.from_diploma( "net_1001", COURSE_STR )
    @grade_admin = Entities.Grades.find_by_course_person( @net.course_id, @admin.login_name )
    assert_not_nil @grade_admin
    assert_equal 10, @grade_admin.mean
    assert_equal %w( 01.02.2003 04.05.2003 04.06.2003 72 admin josue ),
      course.data_get( %w( start end sign duration teacher responsible ) )
    dputs( 0 ){ @course.inspect }
  end

  def test_print_presence
    @maint.print_presence
  end
  
  def test_person_courses
    courses = Entities.Courses.list_courses_for_person( @admin )
    assert_equal [[3, "maint_1204"]], courses

    courses = Entities.Courses.list_courses_for_person( @admin.login_name )
    assert_equal [[3, "maint_1204"]], courses
  end
  
  def test_new_course
    nmaint = Courses.create_ctype("1201", @maint_t)
    assert_equal( {:duration=>72, :course_id=>5, :contents=>"lots of work", 
        :students=>[], :name=>"maint_1201", :ctype => [1] },
      nmaint.to_hash )
  end
	
  def test_prepare_diplomas
    dputs(0){"Checking for diplomas in #{@maint_2.diploma_dir}"}
    @maint_2.prepare_diplomas( false )
    assert_equal 0, Dir.glob( "#{@maint_2.diploma_dir}/*" ).count

    @maint_2.students.push 'josue'
    @maint_2.prepare_diplomas( false )
    assert_equal 0, Dir.glob( "#{@maint_2.diploma_dir}/*" ).count
		
    @grade0 = Grades.save_data({:person_id => @secretaire.person_id,
        :course_id => @maint_2.course_id, :mean => 9})
    @maint_2.prepare_diplomas( false )
    assert_equal 0, Dir.glob( "#{@maint_2.diploma_dir}/*" ).count


    @grade0 = Grades.save_data({:person_id => @secretaire.person_id,
        :course_id => @maint_2.course_id, :mean => 11})
    @secretaire.role_diploma = "Director"
    assert @secretaire, @maint_2.teacher
    @maint_2.prepare_diplomas( false )
    assert_equal 1, Dir.glob( "#{@maint_2.diploma_dir}/*odt" ).count
  end
		
  def test_print_diplomas
    @maint_2.students.push 'josue'
    @grade0 = Grades.save_data({:person_id => @secretaire.person_id,
        :course_id => @maint_2.course_id, :mean => 11})
    @maint_2.prepare_diplomas

    while Dir.glob( "#{@maint_2.diploma_dir}/*" ).count < 3 do
      dputs(0){"Waiting for diplomas"}
      sleep 1
    end
  end
  
  def test_migration_2
    Entities.delete_all_data()

    dputs(0){"Resetting SQLite"}
    SQLite.dbs_close_all
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    SQLite.dbs_open_load_migrate

    @admin = Entities.Persons.create( :login_name => "admin", :password => "super123", 
      :permissions => [ "default", "teacher" ], :first_name => "Admin", :family_name => "The" )
    @linus = Entities.Persons.create( :login_name => "linus", :password => "super123", 
      :permissions => [ "default", "teacher" ], :first_name => "Linus", :family_name => "Torvalds" )
    @maint = Entities.Courses.create( :name => "maint_1204", :start => "19.01.2012", :end => "18.02.2012",
      :teacher => @admin, :assistant => 0,
      :responsible => @linus )
    @maint2 = Entities.Courses.create( :name => "maint_1208", :start => "19.01.2012", :end => "18.02.2012",
      :teacher => @admin, :assistant => @linus,
      :responsible => @linus )
    
    dputs(0){"Courses are #{Courses.search_all.inspect}"}
    
    RPCQooxdooService.add_new_service( Courses,
      "Entities.Courses" )
      
    dputs(0){"Courses are #{Courses.search_all.inspect}"}

    @maint = Courses.find_by_name("maint_1204")
    assert_equal @admin, @maint.teacher
    assert_equal nil, @maint.assistant
    assert_equal @linus, @maint.responsible
    
    @maint2 = Courses.find_by_name("maint_1208")
    assert_equal @admin, @maint2.teacher
    assert_equal @linus, @maint2.assistant
    assert_equal @linus, @maint2.responsible
  end
end
