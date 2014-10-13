require 'test/unit'

class TC_Activity < Test::Unit::TestCase

  def setup
    Entities.delete_all_data
    dputs(1) { 'Resetting SQLite' }
    SQLite.dbs_close_all
    FileUtils.cp('db.testGestion', 'data/compta.db')
    SQLite.dbs_open_load_migrate

    @library = Activities.create(name: 'library', cost: 3_000,
                                 payment_period: %w(yearly), start_type: %w(period_overlap),
                                 card_filename: %w( Diplomas/library_card.odg ))
    @internet = Activities.create(name: 'internet', cost: 10_000,
                                  payment_period: %w(monthly), start_type: %w(payment),
                                  card_filename: %w( Diplomas/library_card.odg))

    @admin = Persons.create(login_name: 'admin', permissions: %w(admin))
    @secretary = Persons.create(login_name: 'secretary', permissions: %w(secretary))
    @accountant = Persons.create(login_name: 'accountant', permissions: %w(accountant))
    @student_1 = Persons.create(login_name: 'student1', permissions: %w(student))
    @student_2 = Persons.create(login_name: 'student2', permissions: %w(student))

    ConfigBase.account_activities = Accounts.create_path('Root::Income::Activities')
  end

  def teardown
  end

  def test_period
    # Friday 10th of October 2014
    d = Date.new(2014, 10, 10)
    d_week = Date.new(2014, 10, 5)
    d_month = Date.new(2014, 10)
    d_year = Date.new(2014)
    assert_equal [d, d], ActivityPayments.get_period(d, :day, 0)
    assert_equal [d-1, d], ActivityPayments.get_period(d, :day, 1)
    assert_equal [d_week, d_week + 6], ActivityPayments.get_period(d, :week, 0)
    assert_equal [d_week, d_week + 6], ActivityPayments.get_period(d, :week, 1)
    assert_equal [d, d_week + 13], ActivityPayments.get_period(d, :week, 2)
    assert_equal [d_month, d_month.next_month - 1],
                 ActivityPayments.get_period(d, :month, 0)
    assert_equal [d_month, d_month.next_month - 1],
                 ActivityPayments.get_period(d, :month, 1)
    assert_equal [d_month, d_month.next_month - 1],
                 ActivityPayments.get_period(d, :month, 2)
    assert_equal [d_month, d_month.next_month - 1],
                 ActivityPayments.get_period(d, :month, 3)
    assert_equal [d, d_month.next_month(2) - 1],
                 ActivityPayments.get_period(d, :month, 4)
    assert_equal [d_year, d_year.next_year - 1],
                 ActivityPayments.get_period(d, :year, 0)
    assert_equal [d_year, d_year.next_year - 1],
                 ActivityPayments.get_period(d, :year, 1)
    assert_equal [d_year, d_year.next_year - 1],
                 ActivityPayments.get_period(d, :year, 2)
    assert_equal [d, d_year.next_year(2) - 1],
                 ActivityPayments.get_period(d, :year, 3)
  end

  def test_add_payment
    d = Date.new(2014, 10, 10)
    d_week = Date.new(2014, 10, 5)
    d_month = Date.new(2014, 10)
    d_year = Date.new(2014)

    pay1 = ActivityPayments.pay(@library, @student_1, @secretary, d)
    pay2 = ActivityPayments.pay(@internet, @student_1, @secretary, d)
    pay3 = ActivityPayments.pay(@internet, @student_2, @secretary, d)

    assert_equal [@library, @internet],
                 ActivityPayments.active_for(@student_1, d).collect { |ap|
                   ap.activity }
    assert_equal [@internet],
                 ActivityPayments.active_for(@student_2, d).collect { |ap|
                   ap.activity }
    assert_equal [], ActivityPayments.active_for(@student_2, d.yesterday)
    assert_equal [nil, nil], @library.start_end(@student_2, d)
    assert_equal [d_year, d_year.next_year - 1], @library.start_end(@student_1, d)
  end

  def test_print
    pay1 = ActivityPayments.pay(@library, @student_1, @secretary)
    assert pay1.print
  end
end