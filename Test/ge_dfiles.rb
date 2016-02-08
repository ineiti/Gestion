require 'test/unit'

class TC_DFiles < Test::Unit::TestCase

  def setup
    Entities.delete_all_data
    DFiles.dir_desc = Dir.pwd + '/descs'
    DFiles.dir_files = Dir.pwd + '/files'
    @dirs = %w(files descs files.save descs.save)
    @dirs.each{|dir| FileUtils.rm_rf dir}
    @dirs.each{|dir| Dir.mkdir dir}
    %w(files descs).each{|dir|
      FileUtils.cp(Dir.glob("dfiles/#{dir}/*"), dir)
      FileUtils.cp(Dir.glob("dfiles/#{dir}/*"), "#{dir}.save")
    }
    DFiles.load
  end

  def teardown
    #@dirs.each{|dir| FileUtils.rm_rf dir}
  end

  def test_load
    descs = DFiles.search_all_
    assert_equal 2, descs.size
    assert_equal 'avg-160203.exe', descs[0].save_file
    assert_equal '1', descs[0].priority

    newdir = Dir.pwd + '/descs.save'
    FileUtils.rm Dir.glob(newdir + '/*')
    DFiles.dir_desc = newdir
    DFiles.changed = true
    DFiles.save

    files_saved = Dir.glob("#{newdir}/*")
    assert_equal 2, files_saved.size
  end

  def test_update_files
    FileUtils.rm Dir.glob(DFiles.dir_files + '/*')
    testfile = DFiles.dir_files + '/test.com'
    IO.write(testfile, 'Hello there')
    DFiles.update_files_from_dir(Dir.pwd + '/files.save')
    assert !File.exists?(testfile)
    assert File.exists?(DFiles.dir_files + '/avg-160203.exe')
    assert_equal 1, DFiles.search_all_.size
  end

  def test_files_prioritze
    DFiles.files_prioritize
  end
end