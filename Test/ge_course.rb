require 'test/unit'
#require 'ftools'


class TC_Course < Test::Unit::TestCase

  def setup
    #    Permission.add( 'default', '.*' )
    Permission.add('student', '.*')
    Permission.add('teacher', '.*')
    Entities.delete_all_data()

    dputs(3) { "Resetting SQLite" }
    SQLite.dbs_close_all
    FileUtils.cp("db.testGestion", "data/compta.db")
    SQLite.dbs_open_load_migrate

    @admin = Entities.Persons.create(:login_name => "admin", :password => "super123",
                                     :permissions => ["default", "teacher"], :first_name => "Admin", :family_name => "The")
    @admin2 = Entities.Persons.create(:login_name => "admin2", :password => "super123",
                                      :permissions => ["default", "teacher"], :first_name => "Admin", :family_name => "The")
    @secretaire = Entities.Persons.create(:login_name => "secretaire", :password => "super",
                                          :permissions => ["default", "teacher"], :first_name => "Le", :family_name => "Secretaire")
    @surf = Entities.Persons.create(:login_name => "surf", :password => "super",
                                    :permissions => ["default"], :first_name => "Internet", :family_name => "Surfer")
    @surf2 = Entities.Persons.create(:login_name => "surf2", :password => "super",
                                     :permissions => ["default"], :first_name => "Internet", :family_name => "Surfer")
    @stud1 = Entities.Persons.create(:login_name => "stud1", :password => "super",
                                     :permissions => ["default"], :first_name => "Internet", :family_name => "Student")
    @stud2 = Entities.Persons.create(:login_name => "stud2", :password => "super",
                                     :permissions => ["default"], :first_name => "Internet", :family_name => "Student")
    @maint_t = Entities.CourseTypes.create(:name => "maint", :duration => 72,
                                           :desciption => "maintenance", :contents => "lots of work",
                                           :filename => ['base_gestion.odt'], :output => "certificate",
                                           :diploma_type => ["simple"],
                                           :account_base => Accounts.create_path("Root::Income::Courses"))
    @maint_2 = Courses.create(:name => "maint_1210", :start => "1.10.2012",
                              :end => "1.1.2013", :sign => "2.1.2012", :teacher => @secretaire,
                              :contents => "lots of work", :description => "maintenance",
                              :duration => 72, :responsible => @secretaire,
                              :ctype => @maint_t)

    @it_101_t = CourseTypes.create(:name => "it-101", :diploma_type => ["accredited"],
                                   :output => %w( label ), :filename => %w( label.odg ),
                                   :contents => "it-101", :description => "windows, word, excel",
                                   :central_host => "http://localhost:3302/label")
    @it_101 = Courses.create_ctype(@it_101_t, "1203")
    @it_101.data_set_hash(:responsible => @secretaire, :teacher => @surf,
                          :start => "1.11.2012", :end => "1.2.2013", :sign => "10.2.2013",
                          :students => %w( secretaire surf ))

    @net_t = CourseTypes.create(:name => "it-301", :description => "Networking")
    @net = Entities.Courses.create(:name => "net_1001",
                                   :ctype => @net_t)

    @base = Entities.Courses.create(:name => "base_1004", :ctype => @it_101_t)

    @maint = Entities.Courses.create(:name => "maint_1204", :start => "19.01.2012", :end => "18.02.2012",
                                     :dow => "lu-ve", :teacher => @secretaire, :ctype => @maint_t)
    @maint.students = %w( admin surf )
    @base.students = %w( admin2 surf )


    @center = Persons.create(:login_name => "foo", :permissions => ["center"],
                             :address => "B.P. 1234", :town => "Sansibar",
                             :phone => "+23599999999", :email => "profeda@gmail.com")
    @center.password = @center.password_plain = "1234"

    @admin_session = Sessions.create(@admin, "default")

    @accountant = Persons.create(:login_name => "accountant",
                                 :permissions => ["accountant"])
  end

  def teardown
    permissions_init
    #Entities.delete_all_data()

    #dputs(1){"Resetting SQLite"}
    #SQLite.dbs_close_all
    #FileUtils.cp( "db.testGestion", "data/compta.db" )
    #SQLite.dbs_open_load_migrate
    #Entities.Persons.save
    #Entities.LogActions.save
  end

  def test_add_student
    assert_equal %w( secretaire surf ), @it_101.students.sort
    assert_equal %w( admin surf ), @maint.students.sort
    assert_equal %w( admin2 surf ), @base.students.sort

    @maint.students_add @surf2
    assert_equal %w( admin surf surf2 ), @maint.students.sort

    @maint.students_add @stud1.login_name
    assert_equal %w( admin stud1 surf surf2 ), @maint.students.sort

    @base.students_add [@stud1, @stud2]
    assert_equal %w( admin2 stud1 stud2 surf ), @base.students.sort

    @base.students_del [@stud1, @stud2]
    assert_equal %w( admin2 surf ), @base.students.sort

    @base.students_add [@stud1.login_name, @stud2]
    assert_equal %w( admin2 stud1 stud2 surf ), @base.students.sort
  end

  def test_print
    View.CourseModify.rpc_button_print_student(@admin_session,
                                               {'name' => @it_101.name})
  end

  def test_search
    courses_admin2 = Entities.Courses.search_by_students("admin2")
    assert_equal 1, courses_admin2.length
    RPCQooxdooHandler.request(1, "View.CourseModify", "button", [["default", "bulk_students",
                                                                  {"name" => "net_1001", "names" => "Dmin A"}]])
    RPCQooxdooHandler.request(1, "View.CourseModify", "button", [["default", "create_new",
                                                                  {"name" => "net_1001", "double_name" => "Dmin A"}]])
    courses_admin2 = Entities.Courses.search_by_students("admin2")
    courses_admin3 = Entities.Courses.search_by_students("admin3")
    courses_surf = Entities.Courses.search_by_students("surf")
    assert_equal 1, courses_admin2.length, Courses.search_all.inspect
    assert_equal 1, courses_admin3.length, Courses.search_all.inspect
    assert_equal 3, courses_surf.length
  end

  COURSE_STR = "base_gestion\nAdmin The\n    Le Secretaire\n    72\n    Cours de base\n    Word\nExcel\nLinux\n\n    1er février 03\n    4 mai 03\n    4 juin 03\nP Admin The\n\nNP Internet Surfer\nhttp://ndjair.net\n"

  # Check different assertions of missing stuff and students
  def test_diploma_export
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

    assert_equal "base_gestion\nAdmin The\n    Le Secretaire\n    72\n    Cours de base\n    Word\nExcel\nLinux\n\n    1er février 03\n    4 mai 03\n    4 juin 03\n",
                 @net.export_diploma

    @net.students = %w( admin surf )

    Entities.Grades.save_data({:student => @admin,
                               :course => @net, :means => [11]})
    Entities.Grades.save_data({:student => @surf,
                               :course => @net, :means => [9], :remark => "http://ndjair.net"})

    assert_equal COURSE_STR, @net.export_diploma
  end

  def notest_diploma_import
    # TODO:
    # As soon as value_entity are known to work OK, one has to replace
    # Course.teacher and Course.responsible with value_entity_person
    course = Courses.from_diploma("net_1001", COURSE_STR)
    @grade_admin = Entities.Grades.match_by_course_person(@net, @admin)
    assert_not_nil @grade_admin
    assert_equal 10, @grade_admin.mean
    assert_equal %w( 01.02.2003 04.05.2003 04.06.2003 72 admin secretaire ),
                 course.data_get(%w( start end sign duration teacher responsible ))
    dputs(1) { @course.inspect }
  end

  def test_print_presence
    assert_equal "/tmp/0-presence_sheet_small.pdf", @maint.print_presence
  end

  def test_person_courses
    courses = Entities.Courses.list_courses_for_person(@admin)
    assert_equal [[@maint.id, "maint_1204"]], courses

    courses = Entities.Courses.list_courses_for_person(@admin.login_name)
    assert_equal [[@maint.id, "maint_1204"]], courses
  end

  def test_new_course
    nmaint = Courses.create_ctype(@maint_t, "1201")
    assert_equal({:duration => 72, :course_id => 6, :contents => "lots of work",
                  :students => [], :name => "maint_1201", :ctype => [1],
                  :salary_teacher => nil, :cost_student => nil},
                 nmaint.to_hash)

    nmaint2 = Courses.create_ctype(@maint_t, "1201")
    assert_equal "maint_1201-2", nmaint2.name

    ConfigBase.add_function(:course_server)
    it_101 = Courses.create_ctype(@it_101_t, "1202", @surf)
    assert_equal({:ctype => [2],
                  :course_id => 8,
                  :students => [],
                  :name => "it-101_1202",
                  :contents => "it-101",
                  :description => "windows, word, excel",
                  :salary_teacher => nil, :cost_student => nil}, it_101.to_hash)

    it_101 = Courses.create_ctype(@it_101_t, "1202", @center)
    assert_equal({:ctype => [2],
                  :course_id => 9,
                  :students => [],
                  :center => [@center.id],
                  :name => "foo_it-101_1202",
                  :contents => "it-101",
                  :description => "windows, word, excel",
                  :salary_teacher => nil, :cost_student => nil}, it_101.to_hash)
  end

  def test_create_account
    ConfigBase.add_function :accounting_courses
    nmaint = Courses.create_ctype(@maint_t, "1201")

    assert_equal "Root::Income::Courses::maint_1201", nmaint.entries.get_path
  end

  def test_prepare_diplomas
    dputs(1) { "Checking for diplomas in #{@maint_2.dir_diplomas}" }
    dputs(5) { @maint_2.inspect }
    dputs(5) { Grades.search_all.inspect }
    @maint_2.prepare_diplomas(false)
    @maint_2.thread.join
    assert_equal 0, Dir.glob("#{@maint_2.dir_diplomas}/*").count

    @maint_2.students_add 'secretaire'
    @maint_2.prepare_diplomas(false)
    @maint_2.thread.join
    assert_equal 0, Dir.glob("#{@maint_2.dir_diplomas}/*").count

    @grade0 = Grades.save_data({:student => @secretaire,
                                :course => @maint_2, :means => [9]})
    @maint_2.prepare_diplomas(false)
    @maint_2.thread.join
    assert_equal 0, Dir.glob("#{@maint_2.dir_diplomas}/*").count


    @grade0 = Grades.save_data({:student => @secretaire,
                                :course => @maint_2, :means => [11]})
    @secretaire.role_diploma = "Director"
    assert @secretaire, @maint_2.teacher.inspect
    @maint_2.prepare_diplomas(false)
    @maint_2.thread.join
    assert_equal 1, Dir.glob("#{@maint_2.dir_diplomas}/*odt").count
  end

  def test_print_diplomas
    ConfigBase.add_function :course_server

    @maint_2.students_add 'secretaire'
    Grades.search_all.each { |g|
      dputs(1) { g.inspect }
    }
    @grade0 = Grades.save_data({:student => @secretaire,
                                :course => @maint_2, :means => [11]})
    Grades.search_all.each { |g|
      dputs(1) { g.inspect }
      dputs(1) { "Grade #{g.grade_id}: #{g.course.name} - #{g.student.login_name}" }
    }
    @maint_2.prepare_diplomas

    while Dir.glob("#{@maint_2.dir_diplomas}/*").count < 3 do
      dputs(1) { "Waiting for diplomas" }
      sleep 1
    end
  end

  def test_migration_2
    Entities.delete_all_data()

    dputs(1) { "Resetting SQLite" }
    SQLite.dbs_close_all
    FileUtils.cp("db.testGestion", "data/compta.db")
    SQLite.dbs_open_load_migrate

    @admin = Entities.Persons.create(:login_name => "admin", :password => "super123",
                                     :permissions => ["default", "teacher"], :first_name => "Admin", :family_name => "The")
    @linus = Entities.Persons.create(:login_name => "linus", :password => "super123",
                                     :permissions => ["default", "teacher"], :first_name => "Linus", :family_name => "Torvalds")
    @maint = Entities.Courses.create(:name => "maint_1204", :start => "19.01.2012", :end => "18.02.2012",
                                     :teacher => @admin, :assistant => 0,
                                     :responsible => @linus)
    @maint2 = Entities.Courses.create(:name => "maint_1208", :start => "19.01.2012", :end => "18.02.2012",
                                      :teacher => @admin, :assistant => @linus,
                                      :responsible => @linus)

    dputs(1) { "Courses are #{Courses.search_all.inspect}" }
    RPCQooxdooService.migrate("Entities.Courses")
    dputs(1) { "Courses are #{Courses.search_all.inspect}" }

    @maint = Courses.match_by_name("maint_1204")
    assert_equal @admin, @maint.teacher
    assert_equal nil, @maint.assistant
    assert_equal @linus, @maint.responsible

    @maint2 = Courses.match_by_name("maint_1208")
    assert_equal @admin, @maint2.teacher
    assert_equal @linus, @maint2.assistant
    assert_equal @linus, @maint2.responsible
  end

  def test_spaces
    @ct = CourseTypes.create(:name => "base arabe 1")
    assert_equal "base_arabe_1", @ct.name

    @c1 = Courses.create(:name => "base_arabe 1201", :ctype => @ct)
    assert_equal "base_arabe_1201", @c1.name
  end

  def test_duration_adds
    dputs(1) { "@maint is #{@maint.inspect}" }
    @maint.dow = ['lu-me-ve']
    @maint.end = '30.01.2012'
    assert_equal [6, [[/1001/, 0], [/1002/, 2], [/1003/, 4], [/1004/, 7],
                      [/1005/, 9], [/1006/, 11]]],
                 @maint.get_duration_adds

    @maint.dow = ['lu-ve']
    @maint.end = '30.01.2012'
    assert_equal [10,
                  [[/1001/, 0], [/1002/, 1], [/1003/, 2], [/1004/, 3], [/1005/, 4],
                   [/1006/, 7], [/1007/, 8], [/1008/, 9], [/1009/, 10], [/1010/, 11]]],
                 @maint.get_duration_adds
  end

  def test_zip
    center = @center.login_name
    @maint_2.students = %w( admin surf secretaire )
    @maint_2.center = @center
    @maint_t.diploma_type = [:files]

    %x[ rm -rf Exas ]
    FileUtils.mkdir 'Exas'

    file = @maint_2.zip_create(for_server: false)
    file_tmp = "/tmp/#{file}"
    file_exa_tmp = "/tmp/exa-#{file}"
    assert_not_nil file

    FileUtils.copy(file_tmp, file_exa_tmp)
    @maint_2.zip_read

    assert File.exists?("Exas/#{@maint_2.name}")
    assert(!File.exists?("Exas/#{@maint_2.name}/#{center}-admin"))

    FileUtils.copy(file_tmp, file_exa_tmp)
    Zip::File.open(file_exa_tmp) { |z|
      %w( admin surf ).each { |s|
        p = "exa-#{@maint_2.name}/#{s}"
        z.file.open("#{p}/first.doc", "w") { |f| f.puts 'Hello world' }
      }
    }

    @maint_2.zip_read
    %w( admin surf ).each { |s|
      dir = "Exas/#{@maint_2.name}/#{s}"
      assert File.exists? dir
      assert File.exists? "#{dir}/first.doc"
    }
    dir = "Exas/#{@maint_2.name}/secretaire"
    assert File.exists?(dir)
    assert !File.exists?("#{dir}/first.doc")

    assert ['first.doc'], @maint_2.exam_files('admin').join(':')
    assert [], @maint_2.exam_files('secretaire').join(':')
  end

  def test_label
    ConfigBase.add_function :course_server

    @it_101_t.diploma_type = %w( accredited )
    dputs(1) { "it_101 is #{@it_101.class}" }
    @it_101.students_add 'secretaire'
    @grade0 = Grades.save_data({:student => @secretaire,
                                :course => @it_101, :mean => 11, :means => [11]})
    @it_101.prepare_diplomas(false)

    while (files = Dir.glob("#{@it_101.dir_diplomas}/*")).count < 3 do
      dputs(1) { "Waiting for diplomas - #{files.inspect}" }
      sleep 1
    end
  end

  def test_get_url_label
    ConfigBase.add_function :course_server

    @grade0 = Grades.create({:student => @secretaire,
                             :course => @maint_2, :mean => 11, :means => [11]})

    dputs(1) { "grade0 is #{@grade0.inspect}" }
    assert @grade0.random
    assert @grade0.get_url_label =~ /^http:\/\//
    dputs(1) { "URL-label is #{@grade0.get_url_label}" }
    assert @grade0.random
  end

  def test_random_match
    ConfigBase.add_function :course_server

    @grade0 = Grades.create({:student => @secretaire,
                             :course => @maint_2, :mean => 11, :means => [11]})

    assert @grade0.random
    assert_equal @grade0, Grades.match_by_random(@grade0.random)
  end

  def test_print_label
    ConfigBase.add_function :course_server
    @grade0 = Grades.create({:student => @secretaire,
                             :course => @maint_2, :mean => 11, :means => [11]})
    @maint_t.data_set_hash({:output => ['label'], :central_name => 'foo',
                            :central_host => 'label.profeda.org', :filename => ['label.odg'],
                            :diploma_type => ['simple']})
    @maint_2.students_add 'secretaire'
    Grades.search_all.each { |g|
      dputs(1) { "Grade #{g.grade_id}: #{g.course.name} - #{g.student.login_name}" }
    }
    @maint_2.prepare_diplomas

    while (files = Dir.glob("#{@maint_2.dir_diplomas}/*")).count < 3 do
      dputs(1) { "Waiting for diplomas - #{files.inspect}" }
      sleep 1
    end
  end

  def test_files_move
    @maint_t.data_set_hash({:output => ['label'], :central_name => 'foo',
                            :central_host => 'label.profeda.org', :filename => ['label.odg'],
                            :diploma_type => ['simple']})
    students = %w( secretaire admin surf )
    @maint_2.students.concat students

    %x[ rm -rf #{@maint_2.dir_exas} ]
    %x[ rm -rf #{@maint_2.dir_exas_share} ]

    @maint_2.exas_prepare_files
    assert !File.exists?(@maint_2.dir_exas)
    assert File.exists?(@maint_2.dir_exas_share)
    students.each { |s|
      student_dir = "#{@maint_2.dir_exas_share}/#{s}"
      assert File.exists?(student_dir)
      FileUtils.touch "#{student_dir}/exa.doc"
    }

    @maint_2.exas_fetch_files
    assert File.exists?(@maint_2.dir_exas)
    assert !File.exists?(@maint_2.dir_exas_share)
    students.each { |s|
      student_dir = "#{@maint_2.dir_exas}/#{s}"
      assert File.exists?(student_dir)
      assert File.exists?("#{student_dir}/exa.doc")
    }
  end

  def test_sync
    @port = 3302
    main = Thread.new {
      QooxView::startWeb(@port)
    }
    dputs(1) { "Starting at port #{@port}" }
    sleep 1
    cname = "#{@center.login_name}_"

    @maint_t.data_set_hash({:output => ['label'],
                            :central_host => "http://localhost:#{@port}/label", :filename => ['label.odg'],
                            :name => 'it-101',
                            :diploma_type => ['accredited']})

    students = %w( secretaire admin surf )
    @maint_2.students.concat students
    @grade0 = Grades.create({:student => @secretaire,
                             :course => @maint_2, :mean => 11, :means => [11]})

    @maint_2.exas_prepare_files
    @maint_2.exas_fetch_files
    students[0..1].each { |s|
      student_dir = "#{@maint_2.dir_exas}/#{s}"
      FileUtils.touch("#{student_dir}/exa.doc")
    }

    assert_equal [], Persons.search_by_login_name("^#{cname}")
    assert_equal nil, Courses.find_by_name("^#{cname}")

    @maint_2.sync_do(false)

    main.kill.join

    foo_maint = Courses.find_by_name("^#{cname}")
    names = Persons.search_by_login_name("^#{cname}").collect { |p|
      p.login_name
    }
    assert_equal ["foo_secretaire", "foo_admin", "foo_surf"], names
    assert_equal "foo_maint_1210", foo_maint.name
    assert_equal "foo", foo_maint._center.login_name

    dputs(1) { "Diploma-dir is #{foo_maint.dir_exas}" }

    assert File.exists? foo_maint.dir_exas
  end

  # Syncs, aborts and sends again, checking if only new files are transmitted
  def test_resync_files
    students = %w( secretaire admin surf )
    @maint_2.students = students

    @maint_2.name = "foo_#{@maint_2.name}"
    dputs(3) { "Clearing directory #{@maint_2.dir_exas}" }
    FileUtils.rm_rf @maint_2.dir_exas
    @maint_2.check_students_dir
    students[0..1].each { |s|
      student_dir = "#{@maint_2.dir_exas}/#{s}"
      dputs(2) { "Adding a simple doc to #{student_dir}" }
      FileUtils.touch("#{student_dir}/exa.doc")
    }

    # Test md5-sums
    files_hash = @maint_2.md5_exams
    assert_equal files_hash, JSON.parse(Label.field_save({course: @maint_2.name, user: 'foo',
                                                          field: 'exams_here'}).
                                            sub(/^OK: /, ''))
    assert_equal({'secretaire' => [%w(exa.doc d41d8cd98f00b204e9800998ecf8427e)],
                  'admin' => [%w(exa.doc d41d8cd98f00b204e9800998ecf8427e)],
                  'surf' => []}, files_hash)

    # Test normal creation of zip-file
    @maint_2.name = @maint_2.name.sub(/^foo_/, '')
    dputs(3) { "Clearing directory #{@maint_2.dir_exas}" }
    FileUtils.rm_rf @maint_2.dir_exas
    @maint_2.check_students_dir
    students[0..1].each { |s|
      student_dir = "#{@maint_2.dir_exas}/#{s}"
      dputs(2) { "Adding a simple doc to #{student_dir}" }
      FileUtils.touch("#{student_dir}/exa.doc")
    }
    zip = @maint_2.zip_create
    Zip::File.open("/tmp/#{zip}") { |f|
      assert_nothing_raised {
        f.read('exa-foo_maint_1210/foo_secretaire/exa.doc')
        f.read('exa-foo_maint_1210/foo_admin/exa.doc')
      }
      assert_equal [], JSON.parse(f.read('exa-foo_maint_1210/files_excluded'))
    }

    # Test ignoring files already there
    FileUtils.touch("#{@maint_2.dir_exas}/surf/exa.doc")
    FileUtils.touch("#{@maint_2.dir_exas}/secretaire/exa2.doc")
    zip = @maint_2.zip_create(md5sums: files_hash)
    exams = []
    Zip::File.open("/tmp/#{zip}") { |zf|
      zf.each { |f|
        f.name =~ /\.doc$/ and exams.push f.name
      }
      assert_equal %w(admin/exa.doc secretaire/exa.doc),
                   JSON.parse(zf.read('exa-foo_maint_1210/files_excluded'))
    }
    assert_equal %w(exa-foo_maint_1210/foo_secretaire/exa2.doc exa-foo_maint_1210/foo_surf/exa.doc),
                 exams

    # Test adding files already there but with other md5sum
    files_hash = @maint_2.md5_exams
    File.open("#{@maint_2.dir_exas}/surf/exa.doc", 'w') { |f| f.write('hello') }
    zip = @maint_2.zip_create(md5sums: files_hash)
    exams = []
    Zip::File.open("/tmp/#{zip}") { |zf|
      zf.each { |f|
        f.name =~ /\.doc$/ and exams.push f.name
      }
      assert_equal %w( admin/exa.doc secretaire/exa.doc secretaire/exa2.doc),
                   JSON.parse(zf.read('exa-foo_maint_1210/files_excluded'))
    }
    assert_equal %w(exa-foo_maint_1210/foo_surf/exa.doc), exams

    # Test merging of directory with additional (to-be-deleted) files and
    # copying of files not transferred but locally available
    files_hash = @maint_2.md5_exams
    FileUtils.touch("#{@maint_2.dir_exas}/secretaire/exa3.doc")
    FileUtils.touch("#{@maint_2.dir_exas}/secretaire/exa5.doc")
    zip = @maint_2.zip_create(for_server: false, md5sums: files_hash)
    FileUtils.touch("#{@maint_2.dir_exas}/secretaire/exa4.doc")
    FileUtils.rm("#{@maint_2.dir_exas}/secretaire/exa5.doc")
    @maint_2.zip_read("/tmp/#{zip}")
    assert File.exists?("#{@maint_2.dir_exas}/surf/exa.doc"),
           "Didn't restore non-transferred file"
    assert File.exists?("#{@maint_2.dir_exas}/secretaire/exa3.doc"),
           "Didn't add transferred file"
    assert File.exists?("#{@maint_2.dir_exas}/secretaire/exa5.doc"),
           "Didn't add transferred but deleted file"
    assert !File.exists?("#{@maint_2.dir_exas}/secretaire/exa4.doc"),
           "Didn't delete additional file"
  end

  def write_file(name, str = 'Hello world, how are you?')
    File.open(name, 'w') { |f|
      f.write(str)
    }
  end

  def test_sync_exams
    students = %w( admin secretaire surf )
    @maint_2.students = students

    # Test normal creation of zip-file
    @maint_2.name = @maint_2.name.sub(/^foo_/, '')
    dputs(3) { "Clearing directory #{@maint_2.dir_exas}" }
    FileUtils.rm_rf @maint_2.dir_exas
    @maint_2.check_students_dir
    students[0..1].each { |s|
      student_dir = "#{@maint_2.dir_exas}/#{s}"
      dputs(2) { "Adding a simple doc to #{student_dir}" }
      write_file("#{student_dir}/exa.doc")
    }
    write_file("#{@maint_2.dir_exas}/secretaire/exa2.doc", 'hi')
    write_file("#{@maint_2.dir_exas}/surf/exa.doc")
    write_file("#{@maint_2.dir_exas}/surf/zpresentation.doc")

    ConfigBase.max_upload_size = 10
    zips = @maint_2.zip_create_chunks(@maint_2.md5_exams, {})
    assert_equal 4, zips.length

    files = %w( exa-foo_maint_1210/foo_admin/exa.doc exa-foo_maint_1210/foo_secretaire/exa.doc
        exa-foo_maint_1210/foo_secretaire/exa2.doc,exa-foo_maint_1210/foo_surf/exa.doc
        exa-foo_maint_1210/foo_surf/zpresentation.doc )
    files_server = []
    zips.each { |zip|
      dputs(2) { "Working with #{zip}" }
      exams = []
      excluded = ''
      Zip::File.open("/tmp/#{zip}") { |zf|
        zf.each { |f|
          f.name =~ /\.doc$/ and exams.push f.name
        }
        excluded = JSON.parse(zf.read('exa-foo_maint_1210/files_excluded'))
      }
      assert_equal files.first, exams.join(',')
      assert_equal files_server.join(','), excluded.join(',')
      files_server.push files.shift.gsub(/exa-foo_maint_1210.foo_/, '')
    }
  end

  def test_random_id
    @port = 3302
    main = Thread.new {
      QooxView::startWeb(@port)
    }
    dputs(1) { "Starting at port #{@port}" }
    sleep 1
    cname = "#{@center.login_name}_"

    @maint_t.data_set_hash({:output => ['label'],
                            :central_host => "http://localhost:#{@port}/label", :filename => ['label.odg'],
                            :name => 'it-101',
                            :diploma_type => ['accredited']})

    students = %w( secretaire admin surf )
    @maint_2.students.concat students
    @grade0 = Grades.create({:student => @secretaire,
                             :course => @maint_2, :mean => 11, :means => [11]})
    @grade1 = Grades.create({:student => @admin,
                             :course => @maint_2, :mean => 15, :means => [15]})

    @maint_2.exas_prepare_files
    @maint_2.exas_fetch_files
    students[0..1].each { |s|
      student_dir = "#{@maint_2.dir_exas}/#{s}"
      FileUtils.touch("#{student_dir}/exa.doc")
    }

    assert_equal nil, @grade0.random
    assert_equal [], Persons.search_by_login_name("^#{cname}")
    assert_equal nil, Courses.find_by_name("^#{cname}")

    ConfigBase.add_function :course_server
    @maint_2.sync_do

    foo_maint = Courses.find_by_name("^#{cname}")
    foo_grade = Grades.match_by_course_person(foo_maint, 'foo_secretaire')
    names = Persons.search_by_login_name("^#{cname}").collect { |p|
      p.login_name
    }
    assert_equal %w(foo_secretaire foo_admin foo_surf), names
    assert_equal 'foo_maint_1210', foo_maint.name
    assert_equal 'foo', foo_maint._center.login_name
    Grades.search_all.each { |g|
      dputs(1) { "Grade #{g.grade_id}: #{g.course.name}-#{g.student.login_name}-#{g.random}" }
    }
    assert foo_grade.random
    assert @grade0.random
    assert_equal foo_grade.random, @grade0.random

    random = foo_grade.random

    ConfigBase.add_function :course_client
    @grade0.means = [11]
    assert_equal random, @grade0.random
    @grade0.means = [14]
    assert_equal nil, @grade0.random

    ConfigBase.add_function :course_server
    dputs(1) { "ConfigBase has #{ConfigBase.get_functions.inspect}" }
    @maint_2.sync_do
    assert_equal random, @grade0.random

    @grade0.remark = 'foo'
    assert_equal random, @grade0.random
    ConfigBase.add_function :course_client
    @grade0.remark = 'foo'
    assert_equal random, @grade0.random
    @grade0.remark = 'foo bar'
    assert_equal nil, @grade0.random

    ConfigBase.add_function :course_server
    dputs(1) { "ConfigBase has #{ConfigBase.get_functions.inspect}" }
    @maint_2.sync_do
    assert_equal random, @grade0.random

    main.kill
  end

  def test_wrong_password
    @port = 3302
    main = Thread.new {
      QooxView::startWeb(@port)
    }
    dputs(1) { "Starting at port #{@port}" }
    sleep 1

    @it_101.ctype.central_host = "http://localhost:#{@port}/label"
    dputs(1) { @center.inspect }
    dputs(1) { Persons.find_by_permissions(:center).inspect }
    assert @it_101.sync_do
    assert_equal('<li>Transferring responsibles: OK</li><li>Transferring users: OK</li>' +
                     '<li>Transferring course: OK</li><li>Demander ce qui existe déjà: OK</li>' +
                     '<li>Transferring exams: OK</li>It is finished!',
                 @it_101.sync_state)

    @center.password_plain = ""

    assert !@it_101.sync_do
    assert_equal(
        '<li>Transferring responsibles: Error: authentification',
        @it_101.sync_state)

    @center.password = ""
    assert @it_101.sync_do
    assert_equal('<li>Transferring responsibles: OK</li><li>Transferring users: OK</li>' +
                     '<li>Transferring course: OK</li><li>Demander ce qui existe déjà: OK</li>' +
                     '<li>Transferring exams: OK</li>It is finished!',
                 @it_101.sync_state)

    main.kill
  end

  def test_update_grade
    @port = 3302
    main = Thread.new {
      QooxView::startWeb(@port)
    }
    dputs(1) { "Starting at port #{@port}" }
    sleep 1

    @it_101.ctype.central_host = "http://localhost:#{@port}/label"

    grade = Grades.create({:student => @surf,
                           :course => @it_101, :means => [11]})
    assert !Courses.find_by_name("foo_")
    assert !Persons.match_by_login_name("foo_secretaire")

    @it_101.sync_do

    foo = Courses.find_by_name("foo_")
    foo_surf = Persons.match_by_login_name("foo_surf")
    foo_grade = Grades.match_by_course_person(foo, foo_surf)

    assert_equal [11], foo_grade.means
    grade.means = [12]

    @it_101.sync_do
    assert_equal [12], foo_grade.means

    main.kill
  end

  def test_bulk
    ConfigBase.set_functions([])
    names = ["Dmin A", "Zero", "One Two", "Ten Eleven Twelve", "A B C D",
             "Hélène Méyère", "Ñeri Soustroup"]
    reply = ""
    while names.length > 0
      dputs(4) { "Doing #{names.inspect}" }
      reply = RPCQooxdooHandler.request(1, "View.CourseModify", "button", [["default", "bulk_students",
                                                                            {"name" => "net_1001", "names" => names.join("\n")}]])
      assert_not_nil reply
      names.shift
    end
    bulk = [["zero", "Zero", ""], %w( tone One Two ), ["eten", "Ten", "Eleven Twelve"],
            ["ca", "A B", "C D"], %w( mhelene Hélène Méyère )]
    bulk.each { |b|
      login, first, family = b
      dputs(1) { "Doing #{b.inspect}" }
      p = Persons.match_by_login_name(login)
      dputs(5) { "p is #{p.inspect} - login is #{login.inspect}" }
      assert_not_nil p, login.inspect
      assert_equal login, p.login_name
      assert_equal first, p.first_name
      assert_equal family, p.family_name
      assert_equal %w( student ), p.permissions
    }

    students = Courses.match_by_name('net_1001').students
    assert_equal %w( ca eten mhelene s_eri tone zero ), students.sort
  end

  def test_add_double
    RPCQooxdooHandler.request(1, "View.CourseModify", "button", [["default", "create_new",
                                                                  {"name" => "net_1001", "double_name" => "Dmin A"}]])
    RPCQooxdooHandler.request(1, "View.CourseModify", "button", [["default", "accept",
                                                                  {"name" => "net_1001", "double_proposition" => [@admin.person_id]}]])

    assert_equal %w( admin admin3 ), @net.students.sort
  end

  def test_grade
    @grade0 = Grades.save_data({:student => @secretaire,
                                :course => @net, :means => [11]})
    assert_equal 11, @grade0[:mean]
    @grade1 = Grades.save_data({:student => @surf,
                                :course => @net, :means => [12]})
    assert_equal 12, @grade1[:mean]
    @grade2 = Grades.save_data({:student => @surf,
                                :course => @net, :means => [13]})
    assert_equal 13, @grade2[:mean]
    assert_equal @grade1[:grade_id], @grade2[:grade_id]
  end

  def test_list_students
    assert_equal [["admin2", "Admin The - admin2:super123"],
                  ["surf", "Internet Surfer - surf:super"]], @base.list_students
    assert_equal [[2, "Admin The - admin2:super123"],
                  [4, "Internet Surfer - surf:super"]], @base.list_students(true)
  end

  def test_report_pdf
    ConfigBase.add_function(:accounting_courses)
    assert @secretaire.account_due

    ctype = CourseTypes.create(:name => "base",
                               :account_base => Accounts.create_path("Root::Income::Courses"))
    course = Courses.create_ctype(ctype, "1404")
    course.teacher = @admin
    course.cost_student = 50000
    stu1 = Persons.create(:login_name => "stu1", :first_name => "Student 1")
    stu2 = Persons.create(:login_name => "stu2", :first_name => "Student 2")
    course.students = ["stu1", "stu2"]
    assert course.entries

    date = Date.new(2014, 4, 10)
    Movements.create("For student stu1:", date - 1, 10, course.entries, @secretaire.account_due)
    Movements.create("For student stu2:", date, 20.1, course.entries, @secretaire.account_due)
    Movements.create("For student stu1:", date - 2, 30, course.entries, @secretaire.account_due)

    file = course.report_pdf

    assert file
  end

  def test_payment
    ConfigBase.add_function(:accounting_courses)
    course = Courses.create_ctype(@maint_t, "1312")
    assert_equal 0, @secretaire.account_due.total

    course.payment(@secretaire, @surf, 10000, Date.today)
    assert_equal 10, @secretaire.account_due.total

    course.payment(@secretaire, @surf, 10000, Date.today, true)
    assert_equal 10, @secretaire.account_due.total
  end

  def test_report_list_archive
    ConfigBase.add_function(:accounting_courses)
    @course_acc = Courses.create_ctype(@maint_t, "1312")
    @course_acc.students = ["surf"]

    @course_acc.payment(@secretaire, @surf, 10000, Date.new(2013))
    @course_acc.payment(@secretaire, @surf, 10000, Date.new(2014))
    assert_equal 20, @secretaire.account_due.total
    assert_equal 20, @course_acc.entries.total
    list = @course_acc.report_list
    assert_equal 3, list.length

    Accounts.archive(1, 2014)
    assert_equal 20, @secretaire.account_due.total
    assert_equal 10, @course_acc.entries.total
    list = @course_acc.report_list
    assert_equal 3, list.length
  end

  def test_transfer_student
    ConfigBase.add_function(:accounting_courses)
    @course_acc = Courses.create_ctype(@maint_t, "1312")
    @course_acc2 = Courses.create_ctype(@maint_t, "1401")
    @course_acc.students = ["surf"]

    @course_acc.payment(@secretaire, @surf, 10000, Date.new(2014, 1))

    assert_equal 10, @secretaire.account_due.total
    assert_equal 10, @course_acc.entries.total
    @course_acc.transfer_student("surfs", @course_acc2)
    assert_equal 10, @course_acc.entries.total
    @course_acc.transfer_student("surf", @course_acc2)
    assert(!@course_acc.students.index("surf"))
    assert(@course_acc2.students.index("surf"))
    assert_equal 0, @course_acc.entries.total
    assert_equal 10, @course_acc2.entries.total
    assert_equal 0, @course_acc.entries.movements.size
    assert_equal 1, @course_acc2.entries.movements.size

    Accounts.find_by_path("Root::Income::Courses").dump_rec(true)

    @accountant.get_all_due(@secretaire)
    @course_acc2.payment(@secretaire, @surf, 10000, Date.new(2014, 1, 2))
    @course_acc2.transfer_student("surf", @course_acc)
    assert_equal 20, @course_acc.entries.total
    assert_equal 0, @course_acc2.entries.total
    assert_equal 2, @course_acc.entries.movements.size
    assert_equal 2, @course_acc2.entries.movements.size

    Accounts.find_by_path("Root::Income::Courses").dump_rec(true)

    @course_acc2.students = ["surf"]
    @course_acc2.payment(@secretaire, @surf, 10000, Date.new(2014, 1, 2))
    @course_acc2.transfer_student("surf", @course_acc)
    assert_equal 1, @course_acc2.students.size
    assert_equal 10, @course_acc2.entries.total
    assert_equal 1, @course_acc.students.size
    assert_equal 20, @course_acc.entries.total
  end

  def test_grades
    grade = Grades.create({:student => @secretaire, :course => @maint_2})

    grade = Grades.create({:student => @secretaire, :course => @maint_2,
                           :means => [11]})
    assert_equal 11.0, grade.mean

    grade = Grades.create({:student => @secretaire, :course => @maint_2,
                           :means => [21]})
    assert_equal 20.0, grade.mean
    assert_equal [20.0], grade.means

    grade.means = [10, 30]
    assert_equal [10.0, 20.0], grade.means
    assert_equal 15.0, grade.mean

    grade = Grades.create({:student => @secretaire, :course => @maint_2,
                           :means => [10, 30]})
    assert_equal 15.0, grade.mean
    assert_equal [10.0, 20.0], grade.means
  end

  def test_move_student
    ConfigBase.add_function(:accounting_courses)
    @course_acc = Courses.create_ctype(@maint_t, '1312')
    @course_acc.students = %w(surf surf2)

    @course_acc.payment(@secretaire, @surf, 10000, Date.new(2013, 1))

    assert_equal 10, @secretaire.account_due.total
    assert_equal 10, @course_acc.entries.total
    assert_equal 10, @course_acc.student_paid('surf').first.value
    assert_equal 0, @course_acc.student_paid('surf2').length

    @course_acc.move_payment('surf', 'surf2')

    assert_equal 10, @secretaire.account_due.total
    assert_equal 10, @course_acc.entries.total
    assert_equal 10, @course_acc.student_paid('surf2').first.value
    assert_equal 0, @course_acc.student_paid('surf').length

    @accountant.get_all_due(@secretaire)

    assert_equal 0, @secretaire.account_due.total
    assert_equal 10, @course_acc.entries.total
    assert_equal 10, @course_acc.student_paid('surf2').first.value
    assert_equal 0, @course_acc.student_paid('surf').length

    @course_acc.move_payment('surf2', 'surf')

    assert_equal 10, @course_acc.entries.total
    assert_equal 1, @course_acc.student_paid('surf').length
    assert_equal 10, @course_acc.student_paid('surf').first.value
    assert_equal 0, @course_acc.student_paid('surf2').length

    Accounts.archive(1, 2014)

    assert_equal 10, @course_acc.entries.total
    assert_equal 10, @course_acc.student_paid('surf').first.value
    assert_equal 0, @course_acc.student_paid('surf2').length

    @course_acc.move_payment('surf', 'surf2')

    assert_equal 10, @course_acc.entries.total
    assert_equal 10, @course_acc.student_paid('surf2').first.value
    assert_equal 0, @course_acc.student_paid('surf').length

    #puts AccountRoot.archive.dump_rec( true ).join("\n")
  end

  def test_ct_fetch
    assert_equal 'Error: no course_type_name given', CourseTypes.icc_fetch({})
    assert_equal "Error: CourseType 123 doesn't exist",
                 CourseTypes.icc_fetch({course_type_names: [%w( 123 ).to_json]})

    assert_equal 'it-101',
                 CourseTypes.icc_fetch({course_type_names: [%w( it-101 ).to_json]}).
                     first._name

    assert_equal 'it-101:it-301',
                 CourseTypes.icc_fetch({course_type_names: [%w( it-101 it-301).to_json]}).
                     map{|ct| ct._name}.join(':')
  end
end
