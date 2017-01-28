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
    @fmentries = []
    %w( windows mac ).each { |base|
      FileUtils.mkdir File.join(dir, base)
      @fmdirs.push FMDirs.create({name: base})
      %w( office utils ).each { |sub|
        subdir = File.join(dir, base, sub)
        @fmdirs.push FMDirs.create({name: sub, parent: base})
        FileUtils.mkdir subdir
        fname = "Test#{counter}.zip"
        FileUtils.touch(File.join(subdir, fname))
        File.open(File.join(subdir, fname + '.file'), 'w') { |f|
          f.write("#{fname}\nhttp://base.com\n\n"+
                      "Description #{counter}\n\n#{base}\n#{sub}\ntag1, tag2")
        }
        counter += 1
      }
    }
    FMEntries.load
    @fmentries = FMEntries.search_all_
  end

  def teardown
    #@dirs.each{|dir| FileUtils.rm_rf dir}
  end

  def test_search_by_path
    dir = FMDirs.search_by_path('office', 'windows')
    assert dir
    assert dir.path.size > 0
  end

  def test_search_by_directory
    entries = FMEntries.search_by_directory(@fmdirs[1])
    assert_equal 1, entries.size
    assert_equal 'Test1.zip.file', entries[0]._name
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
    e = FMEntries.find_by_name('Test1.zip.file')
    assert_equal 'Test1.zip', e._url_file
    assert_equal %w(tag1 tag2), e._tags
  end

  def test_create
    FMEntries.create(name: 'new.com', url_file: 'http://localhost/new.com', url_page: 'http://new.com',
                     description: 'desc', directory: @fmdirs[2], tags: %w(one two three))
    assert_equal 5, FMEntries.search_all.count
    reload
    assert_equal 5, FMEntries.search_all.count
    e = FMEntries.find_by_name('new.com.file')
    assert_equal 'http://localhost/new.com', e._url_file
    assert_equal %w(one two three), e._tags

  end

  def test_entries
    assert_equal 0, @fmdirs[0].entries.size
    assert_equal 1, @fmdirs[1].entries.size
    assert_equal 0, @fmdirs[1].update_files.size
    File.open(File.join(@fmdirs[1].path, 'newfile.exe'), 'w') { |f|}
    assert_equal 1, @fmdirs[1].entries.size
    newentries = @fmdirs[1].update_files
    assert_equal 1, newentries.size
    entries = @fmdirs[1].entries
    assert_equal 2, entries.size
    assert_equal 'newfile.exe.file', entries[1]._name
    assert_equal 0, @fmdirs[1].update_files.size
  end

  def test_update
    assert_equal 2, @fmdirs[0].sub_dirs.size
    Dir.mkdir(File.join(@fmdirs[0].path, 'games'))
    @fmdirs[0].update_dirs
    dirs = @fmdirs[0].sub_dirs
    assert_equal 3, dirs.size
    assert_equal 'games', dirs[2]._name
  end

  def test_filename
    assert_equal 'Test1.zip', @fmentries[0].file_name
    @fmentries[0]._url_file = ':win.zip:http://localhost/test1.zip'
    assert_equal 'win.zip', @fmentries[0].file_name
  end

  def test_delete
    assert_equal 1, @fmdirs[1].entries.size
    @fmentries[0].delete
    assert_equal 0, @fmdirs[1].entries.size

    reload

    assert_equal 0, @fmdirs[1].entries.size
  end

  def test_double
    assert_equal 6, FMDirs.search_all_.size
    FMDirs.create(name: 'windows')
    assert_equal 6, FMDirs.search_all_.size
    FMDirs.create(parent: 'windows', name:'utils')
    assert_equal 6, FMDirs.search_all_.size
    FMDirs.create(parent: 'windows', name:'utils2')
    assert_equal 7, FMDirs.search_all_.size
    FMDirs.create(name: 'windows2')
    assert_equal 8, FMDirs.search_all_.size
  end

  def test_spaces
    FileUtils.touch(File.join(@fmdirs[1].path, 'éducation française verbes.exe'))
    FileUtils.touch(File.join(@fmdirs[1].path, 'éducation française mots.exe'))
    f = @fmdirs[1].update_files
    assert_equal 2, f.size
    f.each{|fi|
      assert fi.name !~ / /
      assert fi.file_name !~ / /
      assert fi.description.size > 0
      assert File.exists?(File.join(@fmdirs[1].path, fi.file_name))
    }
  end

  def test_rename
    @fmentries[0].rename('newname.zip')
    reload
    f = @fmentries[0]
    assert_equal 'http://localhost/newname.zip', f._url_file
    assert_equal 'newname.zip.file', f._name
    assert File.exist?(f.full_path)
    assert File.exist?(f._directory.path(f.file_name))
  end

  def test_subdirs
    Dir.mkdir(@fmdirs[1].path('subdir'))
    assert_equal [], @fmdirs[1].update_files
    assert_equal 1, @fmdirs[1].entries.size
  end

  def reload
    FMEntries.save
    FMDirs.save
    FMEntries.delete_all_data(true)
    assert_equal 0, FMEntries.search_all.count
    dir = 'fmdirs.test'
    FMDirs.dir_base = File.join(Dir.pwd, dir)
    FMDirs.load
    FMEntries.load
  end
end