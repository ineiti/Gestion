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

  def search_by_path(n, p = nil)
    if p
      filter_by(name: "^#{n}$", parent: "^#{p}$").first
    else
      find_by_name("^#{n}$")
    end
  end

  def self.accents_replace(str)
    str = str.downcase.gsub(/ /, '_')
    accents = Hash[*%w( a àáâä e éèêë i ìíîï o òóôöœ u ùúûü c ç ss ß )]
    dputs(4) { "String was #{str}" }
    accents.each { |k, v|
      str.gsub!(/[#{v}]/, k)
    }
    str.gsub!(/[^a-z0-9_\.-]/, '_')
    dputs(4) { "String is #{str}" }
    str
  end
end

class FMDir < Entity
  def path(*f)
    p = [name]
    parent and p.unshift(parent)
    File.join(FMDirs.dir_base, *p, *f)
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
    # dputs_func
    ffiles = []
    fentries = entries
    Dir.glob(File.join(path, '*')).each { |f|
      next if File.directory? f
      f = File.basename(f)
      if f !~ /\.file$/
        dputs(3) { "Found file #{f}" }
        if fentries.select { |e|
          dputs(3) { "Checking with #{e._name} / #{e.file_name}" }
          e.file_name == f
        }.size == 0
          f_sanitized = FMDirs.accents_replace(f)
          if f_sanitized != f
            File.rename(path(f), path(f_sanitized))
          end
          dputs(3) { "Creating entry for #{f}/#{f_sanitized} with dir #{self.inspect}" }
          desc = ''
          if f.size > 16
            desc = f
            desc.sub(/\..*?$/, '')
          end
          ffiles.push FMEntries.create(name: f_sanitized, url_file: "localhost://#{f_sanitized}",
                                       directory: self, tags: [], description: desc)
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
      newdir = FMDirs.create(name: d, parent: name)
      FMEntries.load_dir(newdir)
      newdir.update_files
      fdirs.push newdir
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
    @file_id = 1
    FMDirs.base_dirs.each { |base|
      FMDirs.sub_dirs(base._name).each { |sub|
        load_dir(sub)
      }
    }
  end

  def load_dir(sub)
    Dir.glob(File.join(sub.path, '*.file')).each { |f|
      lines = IO.readlines(f).collect { |l| l.chomp }
      tags = lines[7] || ''
      @data[@file_id] = {
          fmentry_id: @file_id,
          name: File.basename(f),
          url_file: lines[0],
          url_page: lines[1],
          description: lines[3],
          directory: sub,
          tags: tags.split(',').map{|t| t.sub(' ', '')},
          changed: false,
      }
      @file_id += 1
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
    @file_id += 1
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
  def save_file(force = false)
    if changed == true || force
      if !tags || tags == ''
        self._tags = []
      end
      File.open(directory.path(name), 'w') { |f|
        f.write("#{url_file}\n#{url_page}\n\n#{description}\n\n"+
                    "#{directory._parent}\n#{directory._name}\n" +
                    "#{tags.join(', ')}")
      }
      self.changed = false
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

  def rename(new_name)
    nname = FMDirs.accents_replace(new_name)
    File.rename(directory.path(file_name), directory.path(nname))
    File.rename(full_path, directory.path(nname+'.file'))
    self.name = nname + '.file'
    self.url_file = "http://localhost/#{nname}"
    save_file(true)
  end
end