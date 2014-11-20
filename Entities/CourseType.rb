# To change this template, choose Tools | Templates
# and open the template in the editor.

class CourseTypes < Entities
  def setup_data
    value_list_drop :page_format,
                    "[[1,'normal'],[2,'interchanged'],[3,'landscape'],[4,'seascape']]"
    value_str :filename

    value_block :strings
    value_str :name
    value_str :duration
    value_int :tests

    value_block :long
    value_str :description
    value_text :contents

    value_block :central
    value_list_drop :diploma_type, '%w( simple files accredited )'
    value_int :files_needed
    value_list_drop :output, '%w( certificate label )'

    value_block :accounting
    value_int :salary_teacher
    value_int :cost_student

    value_block :account
    value_entity_account :account_base, :drop, :path
  end

  def self.files
    begin
      ddir = Courses.dir_diplomas
      (Dir.glob(ddir + '/*odt') +
          Dir.glob(ddir + '/*odg')).
          collect { |f| f.sub(/^.*\//, '') }
    end
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
end

class CourseType < Entity
  def get_unique
    name
  end
end
