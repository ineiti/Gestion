# Handles a usage-reporter for any date / name / resource file
# This class only holds the configuration necessary to fetch
# all data from the files

require 'zlib'

class Usages < Entities
  def setup_data
    value_str :name
    value_str :file_dir
    value_str :file_glob
    # The filter can start with s, g, v - f is used to denote fields:
    # s/search/replace/
    # gstring_needed
    # vstring_not_wanted
    # fs::regexp::arg
    #  where s is
    #  - date - arg is a strptime compatible interpretation
    #  - name - who accessed it - arg can give a command to translate
    #  - element - what has been accessed
    value_str :file_filter
  end
end

class Usage < Entity
  def fetch_files
    return [] unless File.exists? file_dir.to_s
    Dir.glob("#{file_dir}/#{file_glob}")
  end

  def filter_files
    fetch_files.sort.reverse.map { |logfile|
      filter_file(logfile)
    }.flatten
  end

  def readlines(file)
    File.open(file, 'r') { |f|
      if file =~ /gz$/
        gz = Zlib::GzipReader.new(f)
        result = gz.readlines
      else
        f.readlines
      end
    }
  end

  def filter_file(logfile)
    ddputs(3) { "Filtering file #{logfile}" }
    filters = file_filter.to_s.split(/\n/)
    case filters.first
      when /^g/
        reg = /#{filters.shift[1..-1]}/
        readlines(logfile).select { |l|
          l =~ reg
        }
      when /^v/
        reg = /#{filters.shift[1..-1]}/
        f.readlines(logfile).select { |l|
          !l =~ reg
        }
      else
        log_msg :Usage, "Attention: #{filters.join(':')} doesn't start with grep!"
        readlines(logfile)
    end.map { |l|
      l.chomp!
      fields = {}
      dputs(4) { "Filtering line #{l}" }
      file_filter.to_s.split(/\n/).each { |filter|
        dputs(4) { "Applying filter #{filter.inspect} to #{l.inspect}" }
        case filter
          when /^[sgv]/
            l = Usage.filter_line(l, filter) or break
          when /^f/
            field, regex, arg = filter.split('::')
            fields.merge! Usage.filter_field(l, field[1..-1], regex, arg)
        end
        dputs(4) { "l is now #{l}" }
      }
      (fields).size > 0 ? fields : nil
    }.compact
  end

  def filter_files_cache
    @filter_data ||= filter_files
  end

  def collect_data(from = Date.today - 7, to = Date.today)
    count = Hash.new(0)
    filter_files_cache.select { |f|
      f._date and f._date >= from and f._date <= to
    }.each { |f|
      count[f._element] += 1
    }
    count.to_a.sort { |a, b| b[1] <=> a[1] }
  end

  def self.filter_line(line, filter)
    case filter
      when /^s/
        reg, rep = filter.split('/')[1, 2]
        dputs(4) { "Replacing #{reg.inspect} with #{rep.inspect}" }
        return line.sub(/#{reg}/, rep.to_s)
      when /^g/
        dputs(4) { "grepping #{filter} on #{line}" }
        if !(line =~ /#{filter[1..-1]}/)
          dputs(4) { "Didn't find - bail out" }
          return nil
        end
      when /^v/
        dputs(4) { "grepping -v #{filter}" }
        if line =~ /#{filter[1..-1]}/
          dputs(4) { 'Found it - bail out' }
          return nil
        end
    end
    line
  end

  def self.filter_field(line, field, regex, arg = nil)
    (match = line.match(/#{regex}/) and match.size > 1) or return {}
    dputs(3) { "Found a match: #{match.size} - #{match.inspect}" }
    match = match[1..-1]
    field.split(',').map { |f|
      value = match.shift
      case f
        when /date/
          begin
            {date: Time.strptime(value, arg)}
          rescue ArgumentError => e
            {date: Time.now}
          end
        when /name/
          {name: value}
        when /element/
          {element: value}
      end
    }.inject(:update)
  end
end
