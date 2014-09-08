require 'test/unit'

class TC_Usage < Test::Unit::TestCase

  def setup
    Entities.delete_all_data()
  end

  def teardown

  end

  def new_usage(name, dir, glob, filter)
    Usages.create(:name => name, :file_dir => dir,
                  :file_glob => glob, :file_filter => filter)
  end

  def test_usage
    u1 = new_usage('wiki', 'reports', 'test.log',
                   "g\\.html HTTP\nfname::.*?([0-9\\.]{7,15}).*")
    assert_equal( [{name: '192.168.99.146'} ], u1.filter_files )

    time = Time.strptime( '2014-09-05 20:49:02 +0100',
                          '%Y-%m-%d %H:%M:%S' )
    u1 = new_usage('wiki', 'reports', 'test.log',
                   "g\\.html HTTP\nfdate::.*\\[(.*)\\].*::%d/%b/%Y:%H:%M:%S")
    assert_equal( [{date: time}], u1.filter_files )

    element = 'Portal%253AContents/Portals.html'
    u1 = new_usage('wiki', 'reports', 'test.log',
                   "g\\.html HTTP\nfelement::.*GET.*wiki.(.*) HTTP.*")
    assert_equal( {element: element}, u1.filter_files.first )
  end

  def test_filter_line
    logline = 'wiki.profeda.org is the URL'
    logurl = 'wiki.profeda.org'
    assert_equal logurl,
                 Usage.filter_line(logline, 's/ .*//')

    assert_nil Usage.filter_line( logline, 'ghtml')
    assert_not_nil Usage.filter_line( logline, 'gwiki')

    assert_nil Usage.filter_line( logline, 'vwiki')
    assert_not_nil Usage.filter_line( logline, 'vhtml')
  end

  def test_filter_field
    name = 'foo'
    assert_equal({},
                 Usage.filter_field("name is - #{name}",
                                    'name', '.*:(.*)', nil))

    name = 'foo'
    assert_equal({name: name},
                 Usage.filter_field("name is - #{name}",
                                    'name', '.*- (.*)', nil))
    date = Date.today
    assert_equal({date: date.to_time},
                 Usage.filter_field("Date is - #{date.strftime('%Y%M%D')}",
                                    'date', '.*- (.*)', '%Y%M%D'))

    element = 'one two three'
    assert_equal({element: element},
                 Usage.filter_field("These are my elements - #{element}",
                                    'element', '.*- (.*)', nil))
  end
end