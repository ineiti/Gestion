# DFiles is used to manage the updating of the files-repository on the
# Profeda-installations.
# - sync with a harddisk or over ssh
# - update the file-tree

class DFiles < Entities
  attr_accessor :dir_base, :dir_files, :dir_desc, :url_html

  def setup_data
    value_int :dfile_id
    value_str :desc_file
    value_int :priority
    # url_file holds the url to the file. It can be preceded
    # by a name held between two ":", which will be the
    # save_file-name. Else the save_file-name is the 'basename' of the
    # url_file
    value_str :url_file
    value_str :save_file
    value_str :url_page
    value_str :desc_short
    value_text :desc_long
    # os and category are used to build the dokuwiki-pages
    value_str :os
    value_str :category
    # tags are additional fields
    value_str :tags
    value_int :size

    @dir_base = '/opt/Files'
    @dir_files = @dir_base + '/files'
    @dir_desc = @dir_base + '/desc'
    @url_html = 'http://files.ndjair.net/'
  end

  # searches for all descriptions in @dir_desc
  def load(has_static = true)
    delete_all(true)
    dputs(2) { "Loading descs from #{@dir_desc}" }
    if Dir.exists?(@dir_desc)
      dputs(4) { 'Directory exists' }
      file_id = 1
      Dir.glob("#{@dir_desc}/*.desc").each { |f|
        dputs(4) { "Working on file #{f}" }
        name = File.basename(f)
        lines = IO.readlines(f).collect { |l| l.chomp }
        if lines.size >= 7
          file = {
              dfile_id: file_id,
              desc_file: name,
              priority: name.match(/^./)[0],
              url_file: lines[0],
              url_page: lines[1],
              desc_short: lines[3],
              os: lines[5],
              category: lines[6],
              tags: lines[5..7].join(' ').downcase,
          }
          if file[:url_file][0] == ':'
            su = file[:url_file].match(/^:([^:]*):(.*)$/)
            file[:save_file] = su[1]
            file[:url_file] = su[2]
          else
            file[:save_file] = File.basename(file[:url_file])
          end
          dputs(3) { "Saving description #{file}" }
          @data[file_id] = file
          file_id += 1
        else
          dputs(2) { "Description #{f} has not enough lines, skipping" }
        end
      }
    else
      dputs(2) { "Didn't find directory #{@dir_desc}" }
    end
  end

  # saves back the descriptions to @dir_desc
  def save()
    return unless @changed
    if Dir.exists?(@dir_desc)
      FileUtils.rm(Dir.glob("#{@dir_desc}/*.desc"))
    else
      FileUtils.mkpath(@dir_desc)
    end
    p @data
    @data.each { |k, v|
      File.open("#{@dir_desc}/#{v[:desc_file]}", 'w') { |f|
        if (file = v[:save_file]) != File.basename(v[:url_file])
          v[:url_file] = ":#{file}:#{v[:url_file]}"
        end

        f.puts(v[:url_file], v[:url_page], '',
               v[:desc_short], '',
               v[:os], v[:category], v[:tags])
        if v[:desc_long] != ''
          f.puts(v[:desc_long])
        end
      }
    }
  end

  # updates the descriptions from a directory (probably a mount-point, has to
  # be mounted before)
  def update_desc_from_dir(update_dir)
    return unless Dir.exists?(update_dir)
    Dir.glob(File.join(update_dir, '*.desc')).each { |f|
      name = File.basename(f)
      local_name = File.join(@dir_desc,name)
      if File.size(f) == 0
        # This is a file that has to be removed
        File.rm(local_name)
      else
        File.cp(f, local_name)
      end
    }
    load
  end

  # copies the files from a directory to @dir_files
  def update_files_from_dir(update_dir)
    load()
    unless Dir.exists? @dir_files
      FileUtils.mkpath @dir_files
    end
    # Update all sizes, delete if file is missing
    search_all_.each { |df|
      df.size = 0
      [@dir_files, update_dir].each { |d|
        file = File.join(d, df.save_file)
        if File.exists?(file)
          df.size = File.size(file)
        end
      }
      if df.size == 0
        df.delete
      end
    }

    files_wanted = get_limited_files(get_most_wanted, DFileConfig.limit_size * 2**30)
    files_here = Dir.glob(File.join(@dir_files, '/*')).
        collect { |f| File.basename(f) }
    files_delete = files_here - files_wanted
    files_copy = files_wanted - files_here

    # Delete not used files
    files_delete.each { |f|
      file = File.join(@dir_files, f )
      ddputs(3) { "Deleting file #{file}" }
      FileUtils.rm(file)
    }

    # Copy new files
    files_copy.each { |f|
      file = File.join(update_dir, f)
      ddputs(3) { "Copying file #{file}" }
      FileUtils.cp(file, @dir_files)
    }
    save
  end

  # Uses DFilePriorities to decide which files are most important
  def get_most_wanted

  end

  # Returns the first files so that the total is not above the
  # size_limit
  def get_limited_files(files, size_limit)
    if size_limit > 0
      total_size = files.inject(0){|tot, f| tot += f.size}
      # Prioritize the files
      while total_size > size_limit
        # We have too many files and need to prune some entries
        files.last.delete
      end
    end
    files
  end

  # Takes an array of hash of (filepath, descpath) and deletes all entries
  # that make the sum bigger than maxsize
  def files_prioritize(files, maxsize)
    files.each { |f| f[:size] = File.size(f) }
    while files.inject(0) { |tot, f| f[:size] } > maxsize
      files.delete(files.last)
    end
  end

  def get_size(dir, files)
    files.inject(0) { |tot, file|
      tot += File.size(dir + "/#{file}")
    }
  end

  # creates html-files for downloading the files
  def update_html

  end

  # Returns a hash of the file-content
  def self.hash(name)
    if File.exists?(name)
      return IO.read(name).bytes.inject { |a, b| a + a * b } % (2**64-1)
    end
    return 0
  end
end

class DFile < Entity
  def print
    p self
  end
end

# Singleton entity which holds the configuration
class DFileConfigs < Entities
  def setup_data
    # 0 for no limit, else limit in GBytes
    value_int :limit_size
    # at what time of the day the system should update
    # -1 = no auto_update
    value_int :auto_update
  end

  def migration_1(d)
    d.limit_size = 10
    d.auto_update = -1
  end

  def self.singleton
    first or
        self.create({limit_size: 10, auto_update: -1})
  end
end

class DFileConfig < Entity
  def self.method_missing(m, *args)
    dputs(4) { "#{m} - #{args.inspect} - #{DFileConfigs.singleton.inspect}" }
    if args.length > 0
      DFileConfigs.singleton.send(m, *args)
    else
      DFileConfigs.singleton.send(m)
    end
  end

  def self.respond_to?(cmd)
    DFileConfigs.singleton.respond_to?(cmd)
  end
end

class DFilePriorities < Entities
  def setup_data
    value_int :priority
    value_str :tags
  end
end

class DFilePriority < Entity

end

=begin
files.ndjair.net

- copy from profeda.org to markas-al-nour.org
- only serve completed copies
- copy Antivirus first, then other things

- copy from profeda.org to external hard-disk

- copy from external hard-disk to cubox
- only copy up to N GB of files
- separated into categories
- every category has it’s preference

- present as web-page
- first use dokuwiki
- then use static pages

-> move all .file in one directory
-> move all files in another directory
-> use hard links to re-create the ./update-files-structure
-> update .file-directory using rsync
-> update binary directory according to .file, priority

- priority
- each line contains the tags/directories and a priority
- first lines have highest priority, last lines are pruned first if too much space
- what is more important: a priority of 1 at the end or a priority of 9 at the beginning?
- 1-5 are pruned in order of importance
- 6-9 are more important at the beginning
- 1 at the end
SPACE=10G
windows 1
windows antivirus 2
medias 9

- .file
add a priority-field: 1 is most important, 9 is least important, for each category

                                                                   - decision which files to include
                                                                   1. make list of all files with sizes according to ‘priority’
                                                                   2. if total > SPACE
                                                                   2.1. starting from the last line in ‘priority’, remove 9 through 6, repeat up the list until SPACE is met
                                                                   2.2 if total > SPACE
                                                                   2.2.1 prune ‘priority’ 5 to 1, one priority at the time, from end to beginning, starting with biggest files first

-> make list and delete from end till space-requirement is met:
                                                               - from priority 1 to priority 5 for all lines, collect files, starting with smallest
- from first to last line in list do priorities 6 to 9 from smallest to tallest
=end