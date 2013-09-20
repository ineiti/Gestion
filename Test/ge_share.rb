require 'test/unit'
require '../Info.rb'
require '../Internet.rb'

class TC_share < Test::Unit::TestCase
  def setup
    @info = Info.new
    Entities.delete_all_data()

    Entities.Persons.create( :first_name => "admin", :password => "super123", 
      :permissions => [ "admin" ], :groups => [] )
    Entities.Persons.create( :first_name => "surf", :password => "super",
      :password_plain => "1234", :permissions => [ "internet" ], :groups => [ "share" ] )
    @share_public = Shares.create( :name => "public", :path => "./share_test", :public => ["No"],
      :acl => {"surf" => "rw"} )
  end

  def teardown
  end

  def test_htaccess
    FileUtils.rm_rf( "./share_test" )
    @share_public.add_htaccess
    assert ! File.exists?( "./share_test" )
    FileUtils.mkdir( "./share_test" )
    @share_public.add_htaccess
    assert File.exists? "./share_test/.htaccess"
    assert File.exists? "./share_test/.htpasswd"
  end
end
