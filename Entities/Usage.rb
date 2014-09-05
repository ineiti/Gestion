# Handles a usage-reporter for any date / name / resource file
# This class only holds the configuration necessary to fetch
# all data from the files

class Usages < Entities
  def setup_data
    value_str name
    value str file_dir
    value_str file_glob
    value_str file_filter
  end
end

class Usage < Entity
  def fetch_files
    return [] unless File.exists? file_dir
    Dir.glob("#{file_dir}/#{file_glob}")
  end
end