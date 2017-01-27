# FilesManage holds different classes that store information about the
# managed files.

class FMDirs < Entities
  attr_accessor :dir_base

  def create(fields)
    if search_by_path(fields._name, fields._parent)
      return
    end
    super(fields)
  end

  def setup_data
    @dir_base = '/opt/Files'
    value_str :name
    # If the parent is empty, this is a top-dir
    value_str :parent
  end

  def base_dirs
    # puts @data
    return search_by_parent('^$')
  end

  def sub_dirs(base)
    name = base
    if name.class != String
      name = base._name
    end
    return search_by_parent(name)
  end

  def search_by_path(n, p)
    if p
      filter_by(name: n, parent: p).first
    else
      search_by_name(n).first
    end
  end
end

class FMDir < Entity
  def path
    p = [name]
    parent and p.unshift(parent)
    File.join(FMDirs.dir_base, *p)
  end

  def sub_dirs
    return FMDirs.search_by_parent(name)
  end

  # Returns all entries in that directory
  def entries
    return [] unless parent != ''
    FMEntries.search_all_.select { |e|
      dir = e._directory
      dir._parent == parent && dir._name == name
    }
  end

  # Searches for files that are not an entry yet, adds them
  # and returns the array of new entries.
  def update_files
    ffiles = []
    fentries = entries
    Dir.glob(File.join(path, '*')).each { |f|
      f = File.basename(f)
      if f !~ /\.file$/
        dputs(3) { "Found file #{f}" }
        if fentries.select { |e|
          dputs(3) { "Checking with #{e._name}" }
          e.file_name == f
        }.size == 0
          dputs(3) { "Creating entry for #{f} with dir #{self.inspect}" }
          ffiles.push FMEntries.create(name: f, url_file: "localhost://#{f}", directory: self, tags: [])
        end
      end
    }
    ffiles
  end

  # If it's an OS-directory, it adds all its subdirectories that
  # are not yet stored.
  def update_dirs
    return if parent && parent != ''
    fdirs = []
    Dir.glob(File.join(path, '*/')).each{|d|
      d = File.basename(d)
      if FMDirs.search_by_path(d, name)
        next
      end
      fdirs.push FMDirs.create(name: d, parent: name)
    }
    fdirs
  end
end

class FMEntries < Entities
  self.needs %w(FMDirs)

  def setup_data
    value_str :name
    value_str :url_file
    value_str :url_page
    value_str :description
    value_entity_FMDir :directory
    value_str :tags
    value_bool :changed
  end

  def load(has_static = true)
    file_id = 1
    FMDirs.base_dirs.each { |base|
      FMDirs.sub_dirs(base._name).each { |sub|
        Dir.glob(File.join(sub.path, '*.file')).each { |f|
          lines = IO.readlines(f).collect { |l| l.chomp }
          tags = lines[7] || ''
          @data[file_id] = {
              fmentry_id: file_id,
              name: File.basename(f),
              url_file: lines[0],
              url_page: lines[1],
              description: lines[3],
              directory: sub,
              tags: tags.split(' '),
              changed: false,
          }
          file_id += 1
        }
      }
    }
  end

  def save
    FMEntries.search_all_.each { |e|
      e.save_file
    }
  end

  def create(*args)
    e = super(*args)
    e._changed = true
    e._name = e.file_name + '.file'
    e.save_file
    e
  end

  def search_by_directory(dir)
    FMEntries.search_all_.select{|e|
      d = e._directory
      d._name == dir._name && d._parent == dir._parent
    }
  end
end


class FMEntry < Entity
  def save_file
    if changed == true
      if !tags || tags == ''
        self._tags = []
      end
      File.open(File.join(directory.path, name), 'w') { |f|
        f.write("#{url_file}\n#{url_page}\n\n#{description}\n\n"+
                    "#{directory._name}\n#{directory._parent}\n" +
                    "#{tags.join(' ')}")
      }
    end
  end

  def file_name
    if !url_file
      return name.chomp('.file')
    end
    if url_file =~ /^:(.*?):/
      return $1
    end
    File.basename url_file
  end

  def full_path
    return File.join(directory.path, name)
  end

  def delete
    FileUtils.rm_f File.join(directory.path, file_name)
    FileUtils.rm_f File.join(directory.path, name)
    super
  end
end