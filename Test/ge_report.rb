require 'test/unit'

class TC_Report < Test::Unit::TestCase

  def setup
    Entities.delete_all_data()

    SQLite.dbs_close_all
    FileUtils.cp("db.testGestion", "data/compta.db")
    SQLite.dbs_open_load_migrate

    ConfigBases.init

    ConfigBase.add_function(:accounting_courses)

    @secretary = Entities.Persons.create(:login_name => "secretary", :password => "super",
                                         :permissions => ["default", "teacher", "secretary"],
                                         :first_name => "The", :family_name => "secretary")

    @students = %w( Mahamat Younouss ).collect { |p|
      Persons.create(:login_name => p, :permissions => %w( student ))
    }

    @maint_t = CourseTypes.create(:name => "maint", :duration => 72,
                                  :desciption => "maintenance", :contents => "lots of work",
                                  :file_diploma => ['base_gestion.odt'], :output => "certificate",
                                  :diploma_type => ["simple"],
                                  :account_base => Accounts.create_path("Root::Income::Courses"))

    @maint = Courses.create_ctype(@maint_t, "1404")
    @maint.students = @students

    @root = Accounts.find_by_path("Root")

    @report_simple = Reports.create(:name => "basic",
                                    :accounts => [
                                        ReportAccounts.create(:root => @root, :level => 2,
                                                              :account => Accounts.find_by_path("Root::Income")),
                                    ])
    @report_double = Reports.create(:name => "double",
                                    :accounts => [
                                        ReportAccounts.create(:root => @root, :level => 1,
                                                              :account => Accounts.find_by_path("Root::Income")),
                                        ReportAccounts.create(:root => @root, :level => 0,
                                                              :account => Accounts.find_by_path("Root::Lending"))
                                    ])

    [[0, 10000], [0, 5000], [1, 5000]].each { |s, c|
      @maint.payment(@secretary, @students[s], c)
    }

    #Accounts.dump( true )
  end

  def teardown
  end

  def test_report_list
    assert_equal [[['Root::Income::Courses::maint_1404',
                    [20.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]]],
                 @report_simple.print_list_monthly
    assert_equal [[['Root::Income::Courses', [20.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]],
                  [['Root::Lending', [20.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]],
                  [['Total', [40.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]]],
                 @report_double.print_list_monthly
  end

  def test_heading
    assert_equal %w(Period 2014/09 2014/10 2014/11 2014/12 2015/01 2015/02 2015/03 2015/04 2015/05 2015/06 2015/07 2015/08),
                 @report_simple.print_heading_monthly(Date.new(2014,9)).flatten
  end

  def test_report_pdf
    @report_simple.print_pdf_monthly
    @report_double.print_pdf_monthly
  end
end
