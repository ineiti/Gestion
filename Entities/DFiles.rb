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

    @dir_base = '/opt/Files'
    @dir_files = @dir_base + '/files'
    @dir_desc = @dir_base + '/desc'
    @url_html = 'http://files.ndjair.net/'
  end

  def do_load
    load(false)
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
              tags: lines[7]
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
    Dir.glob("#{update_dir}/*.desc").each { |f|
      name = File.basename(f)
      local_name = "#{@dir_desc}/#{name}"
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
    files_wanted = @data.collect { |k, v| v[:save_file] }
    files_here = Dir.glob("#{@dir_files}/*").collect { |f| File.basename(f) }
    files_delete = files_here - files_wanted
    files_copy = files_wanted - files_here
    files_delete.each { |f|
      FileUtils.rm("#{@dir_files}/#{f}")
    }
    files_copy.each { |f|
      newfile = "#{update_dir}/#{f}"
      if File.exists? newfile
        FileUtils.cp(newfile, @dir_files)
      else
        dputs(1) { "Didn't find #{newfile} - deleting dfile" }
        DFiles.find_by_save_file(File.basename(newfile)).delete
      end
    }
    load
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