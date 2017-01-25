require 'test/unit'

class TC_FilesManage < Test::Unit::TestCase

  def setup
    Entities.delete_all_data

    # Seting up files for tests
    dir = 'fmdirs.test'
    FMDirs.dir_base = File.join(Dir.pwd, dir)
    FileUtils.rm_rf(dir)
    FileUtils.mkdir dir
    counter = 1
    @fmdirs = []
    %w( windows mac ).each { |base|
      FileUtils.mkdir File.join(dir, base)
      @fmdirs.push FMDirs.create({name: base})
      %w( office utils ).each { |sub|
        subdir = File.join(dir, base, sub)
        @fmdirs.push FMDirs.create({name: sub, parent: base})
        FileUtils.mkdir subdir
        File.open(File.join(subdir, "test#{counter}.file"), 'w') { |f|
          f.write("Test#{counter}.zip\nhttp://base.com\n\n"+
                      "Description #{counter}\n\n#{base}\n#{sub}\ntag1 tag2")
        }
        counter += 1
      }
    }
    FMEntries.load
  end

  def teardown
    #@dirs.each{|dir| FileUtils.rm_rf dir}
  end

  def test_load_fmdirs
    assert_equal %w(windows mac), FMDirs.base_dirs.collect { |bd| bd._name }
    assert_equal %w(office utils), FMDirs.sub_dirs('windows').collect { |bd| bd._name }
    assert_equal %w(office utils), FMDirs.sub_dirs(FMDirs.base_dirs[0]).collect { |bd| bd._name }
  end

  def test_load_fmentries
    assert_equal 4, FMEntries.search_all.count
    FMEntries.save
    FMDirs.save
    FMEntries.delete_all_data(true)
    assert_equal 0, FMEntries.search_all.count
    dir = 'fmdirs.test'
    FMDirs.dir_base = File.join(Dir.pwd, dir)
    FMDirs.load
    FMEntries.load
    assert_equal 4, FMEntries.search_all.count
    e = FMEntries.find_by_name('test1.file')
    assert_equal 'Test1.zip', e._url_file
    assert_equal %w(tag1 tag2), e._tags
  end

  def test_create
    FMEntries.create(name: 'new.com', url_file: 'http://localhost/new.com', url_page: 'http://new.com',
                     description: 'desc', directory: @fmdirs[2], tags: %w(one two three))
    assert_equal 5, FMEntries.search_all.count
    FMEntries.save
    FMDirs.save
    FMEntries.delete_all_data(true)
    assert_equal 0, FMEntries.search_all.count
    dir = 'fmdirs.test'
    FMDirs.dir_base = File.join(Dir.pwd, dir)
    FMDirs.load
    FMEntries.load
    assert_equal 5, FMEntries.search_all.count
    e = FMEntries.find_by_name('new.com.file')
    assert_equal 'http://localhost/new.com', e._url_file
    assert_equal %w(one two three), e._tags

  end

  def test_entries
    assert_equal 0, @fmdirs[0].entries.size
    assert_equal 1, @fmdirs[1].entries.size
    assert_equal 0, @fmdirs[1].update.size
    File.open(File.join(@fmdirs[1].path, 'newfile.exe'), 'w') { |f|}
    assert_equal 1, @fmdirs[1].entries.size
    newentries = @fmdirs[1].update
    assert_equal 1, newentries.size
    entries = @fmdirs[1].entries
    assert_equal 2, entries.size
    assert_equal 'newfile.exe', entries[1]._name
    assert_equal 0, @fmdirs[1].update.size
  end
end