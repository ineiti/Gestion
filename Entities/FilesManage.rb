# FilesManage holds different classes that store information about the
# managed files.

class FMDirs < Entities
  attr_accessor :dir_base

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
end

class FMDir < Entity
  def path
    p = [name]
    parent and p.unshift(parent)
    File.join(FMDirs.dir_base, *p)
  end

  # Returns all entries in that directory
  def entries
    return [] unless parent != ''
    FMEntries.search_all_.select { |e|
      dir = e._directory
      dir._parent == parent && dir._name == name
    }
  end

  def search_by_path(n, p)
    FMDirs.filter_by(name: n, parent: p).first
  end

  # Searches for files that are not an entry yet, adds them
  # and returns the array of new entries.
  def update
    ffiles = []
    fentries = entries
    Dir.glob(File.join(path, '*')).each { |f|
      f = File.basename(f)
      if f !~ /\.file$/
        dputs(3) { "Found file #{f}" }
        if fentries.select { |e|
          dputs(3) { "Checking with #{e._name}" }
          e._name == f
        }.size == 0
          dputs(3) { "Creating entry for #{f} with dir #{self.inspect}" }
          ffiles.push FMEntries.create(name: f, url_file: "localhost://#{f}", directory: self, tags: [])
        end
      end
    }
    ffiles
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
          @data[file_id] = {
              fmentry_id: file_id,
              name: File.basename(f),
              url_file: lines[0],
              url_page: lines[1],
              description: lines[3],
              directory: sub,
              tags: lines[7].split(' '),
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
    e.save_file
    e
  end
end


class FMEntry < Entity
  def save_file
    if changed
      File.open(File.join(directory.path, name + '.file'), 'w') { |f|
        f.write("#{url_file}\n#{url_page}\n\n#{description}\n\n"+
                    "#{directory._name}\n#{directory._parent}\n" +
                    "#{tags.join(' ')}")
      }
    end
  end
end