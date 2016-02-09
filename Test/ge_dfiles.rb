require 'test/unit'

class TC_DFiles < Test::Unit::TestCase

  def setup
    Entities.delete_all_data

    # Seting up files for tests
    DFiles.set_dir_base(File.join(Dir.pwd, 'dfiles.test'))
    FileUtils.rm_rf('dfiles.test')
    FileUtils.mkdir 'dfiles.test'
    %w(files descs).each { |dir|
      [dir, "#{dir}.save"].each { |d|
        savedir = File.join('dfiles.test', d)
        Dir.mkdir savedir
        FileUtils.cp(Dir.glob("dfiles/#{dir}/*"), savedir)
      }
    }
    FileUtils.cp('dfiles/priorities', 'dfiles.test')
    DFiles.load
    DFilePriorities.load
    @df_avg = DFiles.find_by_name('avg$')
    @df_avg_rescue = DFiles.find_by_name('avg_rescue')
    @df_driver = DFiles.find_by_name('driver')
    @files = DFiles.search_all_.size
  end

  def teardown
    #@dirs.each{|dir| FileUtils.rm_rf dir}
  end

  def test_load
    descs = DFiles.search_all_
    assert_equal 4, descs.size
    avg = descs.find { |df| df.name =~ /avg$/ }
    assert avg
    assert_equal 'avg-160203.exe', avg.save_file
    assert_equal '2', avg.tags.first.first

    newdir = Dir.pwd + '/descs.save'
    FileUtils.rm Dir.glob(newdir + '/*')
    DFiles.dir_descs = newdir
    DFiles.changed = true
    DFiles.save

    files_saved = Dir.glob("#{newdir}/*")
    assert_equal @files, files_saved.size
  end

  def test_update_files
    FileUtils.rm Dir.glob(DFiles.dir_files + '/*')
    DFiles.update_desc_from_dir(DFiles.dir_descs + '.save')
    testfile = DFiles.dir_files + '/test.com'
    IO.write(testfile, 'Hello there')
    DFiles.update_files_from_dir(DFiles.dir_files + '.save')
    assert !File.exists?(testfile)
    assert File.exists?(DFiles.dir_files + '/avg-160203.exe')
    assert_equal @files - 1, DFiles.search_all_.size
  end

  def test_get_files
    dfp = DFilePriorities.find_by_priority(9)
    assert_equal 1, dfp.get_files.size
  end

  def test_file_priorities
    prios = DFilePriorities.search_all_
    result = [1, 1, 0, 1]
    prios.each { |p|
      files = p.get_files
      dputs(3) { [p, files, result].join('::') }
      assert_equal result.shift, files.size, prios.collect { |p| p.inspect }
    }
  end

  def test_get_tag_prio
    assert_equal 2, @df_avg.get_tag_prio('windows')
    assert_equal 1, @df_avg.get_tag_prio('avg')
    assert_equal nil, @df_avg.get_tag_prio('avg2')
  end

  def test_files_pruning
    files = DFilePriorities.get_most_wanted
    assert_equal 80, files.inject(0) { |tot, f| tot + f.file_size }
    assert_equal 3, files.size
    files = DFiles.get_limited_files(files, 40)
    assert_equal 38, files.inject(0) { |tot, f| tot + f.file_size }
    assert_equal 2, files.size
  end

  def test_get_most_wanted
    files = DFilePriorities.get_most_wanted
    assert_equal 3, files.size
  end

  def test_search_by_all
    files = DFiles.search_by_all(:tags, 'windows antivirus'.split)
    assert_equal 2, files.size
    files = DFiles.search_by_all(:tags, 'windows iso'.split)
    assert_equal 1, files.size
  end

  def test_load_priorities

  end
end