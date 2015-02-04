# To change this template, choose Tools | Templates
# and open the template in the editor.

class CourseTypes < Entities
  def setup_data
    value_list_drop :page_format,
                    "[[1,'normal'],[2,'interchanged'],[3,'landscape'],[4,'seascape']]"
    value_str :filename
    value_str :file_exam

    value_block :strings
    value_str :name
    value_str :duration

    value_block :long
    value_str :description
    value_text :contents

    value_block :central
    value_list_drop :diploma_type, '%w( simple files accredited report )'
    value_list_drop :output, '%w( certificate label )'
    value_list_drop :diploma_lang, '%w( en fr )'

    value_block :lists
    value_str :tests_str
    value_int :tests_nbr
    value_str :files_str
    value_int :files_nbr

    value_block :accounting
    value_int :salary_teacher
    value_int :cost_student

    value_block :account
    value_entity_account :account_base, :drop, :path
  end

  def self.files
    ddir = Courses.dir_diplomas
    Dir.glob(ddir + '/*{odt,odg,ods}').
        collect { |f| f.sub(/^.*\//, '') }
  end

  def set_entry(id, field, value)
    case field.to_s
      when 'name'
        value.gsub!(/[^a-zA-Z0-9_-]/, '_')
    end
    super(id, field, value)
  end

  def listp_profeda_code
    self.search_by_profeda_code('^.+$').collect { |ct|
      [ct.coursetype_id, ct.profeda_code]
    }
  end

  def listp_name
    self.search_by_profeda_code('^$').collect { |ct|
      [ct.coursetype_id, ct.name]
    }.sort { |a, b| a[1].downcase <=> b[1].downcase }
  end

  def migration_1(ct)
    ct.tests = 1
    ct.output = ['certificate']
  end

  def migration_2(ct)
    ct.diploma_type = ['simple']
  end

  def migration_3(ct)
    ct.page_format = [0]
  end

  def migration_4(ct)
    ct.page_format[0] += 1
  end

  # Changed tests to tests_str and files_needed to files_str
  def migration_5_raw(ct)
    if (ct._tests_nbr = ct._tests.to_i) > 0
      ct._tests_str = (1..ct._tests_nbr).collect { |t| "Test #{t}" }.join("\n")
    end
    if (ct._files_nbr = ct._files_needed.to_i) > 0
      ct._files_str = (1..ct._files_nbr).collect { |f| "Files #{f}" }.join("\n")
    end
  end

  def migration_6(ct)
    ct.diploma_lang = ['fr']
  end

  def icc_list(arg)
    list_name
  end

  def icc_fetch(arg)
    if ct_names = arg._course_type_names
      ct_names.collect { |ct|
        self.find_by_name(ct) or return "Error: CourseType #{ct} doesn't exist"
      }
    else
      return 'Error: no course_type_name given'
    end
  end

  def icc_file(arg)
    file = "#{ConfigBase.template_dir}/#{File.basename(arg.name)}"
    if File.exists? file
      IO.read(file)
    else
      return "Error: can't find file"
    end
  end
end

class CourseType < Entity
  def get_unique
    name
  end

  def clean_str(str)
    s = str.to_s.split("\n").
        collect { |s| s.sub(/^\s*/, '').sub(/\s*$/, '') }.
        select { |s| s.length > 0 }
    [s.join("\n"), s.length]
  end

  def tests_str=(str)
    self._tests_str, self.tests_nbr = clean_str(str)
  end

  def tests_arr
    tests_str.to_s.split("\n")
  end

  def files_str=(str)
    self._files_str, self.files_nbr = clean_str(str)
  end

  def files_arr
    files_str.to_s.split("\n")
  end
end
