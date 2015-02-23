require 'test/unit'


class TC_Configbase < Test::Unit::TestCase
  def setup
    Entities.load_all
  end
  
  def teardown
  end

  def test_migration_5
    Entities.delete_all_data
    ACQooxView.check_db

    FileUtils.mkdir_p 'data2'
    IO.write 'data2/MigrationVersions.csv',
             '{"migrationversion_id":1,"class_name":"ConfigBases","version":4}' +
                 "\n"
    IO.write 'data2/ConfigBases.csv',
             '{"configbase_id":1,"functions":[]}' +
                 "\n"
    Entities.load_all
    check = [
    [ConfigBase.account_cash, 'Root::Cash', -1],
    [ConfigBase.account_lending, 'Root::Lending', -1],
    [ConfigBase.account_services, 'Root::Income::Internet', 1] ]
    check.each{|acc, path, mult|
      assert_equal path, acc.get_path
      assert_equal mult, acc.multiplier
    }
  end

  def test_delete_all
    Entities.delete_all_data
    assert ConfigBase.account_cash
  end
end
