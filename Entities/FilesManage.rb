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
    search_all.each{|e|
      if e._changed
        File.open(File.join(e._directory.path, e._name + '.file'), 'w'){|f|
          f.write("#{e._url_file}\n#{e._url_page}\n\n#{e._description}\n\n"+
          "#{e._directory._name}\n#{e._directory._parent}\n" +
          "#{e._tags.join(' ')}")
        }
      end
    }
  end

  def create(*args)
    e = super(*args)
    e._changed = true
    e
  end
end
