# A course has:
# - Beginning, End and days of week
# - Person.Students
# - Teacher and Assistant
# - Classroom

require 'Entity'



class Courses < Entities
  def setup_data
    value_block :name
    value_str :name

    value_block :calendar
    value_date :start
    value_date :end
    value_date :sign
    value_int :duration
    value_list_drop :dow, "%w( lu-me-ve ma-je-sa lu-ve ma-sa )"
    value_list_drop :hours, "%w( 9-12 16-18 9-11 )"
    value_list_drop :classroom, "%w( info1 info2 mobile )"
    # value_entity :classroom, :Rooms, :drop, :name

    value_block :students
    value_list :students

    value_block :teacher
    value_list_drop :teacher, "Entities.Persons.list_teachers"
    value_list_drop :assistant, "['none'] + Entities.Persons.list_assistants"
    value_list_drop :responsible, "Entities.Persons.list_teachers"
    # value_entity :professor, :Persons, :drop, :login_name
    # value_entity :assistant, :Persons, :drop, :login_name

    value_block :content
    value_str :description
    value_text :contents

    value_block :accounting
    value_int :salary_teacher
    value_int :salary_assistant
    value_int :students_start
    value_int :students_finish
  end

  def list_courses
    @data.values.collect{ |d| [ d[:course_id ], d[:name] ] }.sort{|a,b|
      a[1].gsub( /^[^_]*_/, '' ) <=> b[1].gsub( /^[^_]*_/, '' )
    }.reverse
  end

  def list_name_base
    return %w( base maint int net site )
  end

  def self.from_date_fr( str )
    day, month, year = str.split(' ')
    day = day.gsub( /^0/, '' )
    if day == "1er"
      day = "1"
    end
    month = %w( janvier février mars avril mai juin juillet août
    septembre octobre novembre décembre ).index( month ) + 1
    "#{day.to_s.rjust(2, '0')}.#{month.to_s.rjust(2, '0')}.#{year.to_s.rjust(4, '2000')}"
  end

  def self.from_diploma( course_name, course_str )
    dputs 1, "Importing #{course_name}: #{course_str.gsub(/\n/,'*')}"
    course = Entities.Courses.find_by_name( course_name ) or
    Entities.Courses.create( :name => course_name )

    lines = course_str.split( "\n" )
    template = lines.shift
    dputs 1, "Template is: #{template}"
    dputs 1, "lines are: #{lines.inspect}"
    case template
    when /base_gestion/ then
      course.teacher, course.responsible = lines.shift( 2 ).collect{|p|
        Entities.Persons.find_full_name( p )
      }
      if not course.teacher or not course.responsible then
        return nil
      end
      course.teacher, course.responsible = course.teacher.login_name, course.responsible.login_name
      course.duration, course.description = lines.shift( 2 )
      course.contents = ""
      while lines[0].size > 0
        course.contents += lines.shift
      end
      dputs 1, "Course contents: #{course.contents}"
      lines.shift
      course.start, course.end, course.sign =
      lines.shift( 3 ).collect{|d| self.from_date_fr( d ) }
      lines.shift if lines[0].size == 0

      course.students = []
      while lines.size > 0
        grade, name = lines.shift.split( ' ', 2 )
        student = Entities.Persons.find_name_or_create( name )
        course.students.push( student.login_name )
        g = Entities.Grades.find_by_course_person( course.course_id, student.login_name )
        if g then
        g.mean, g.remark = Entities.Grades.grade_to_mean( grade ), lines.shift
        else
          Entities.Grades.create( :course_id => course.course_id, :person_id => student.person_id,
          :mean => Entities.Grades.grade_to_mean( grade ), :remark => lines.shift )
        end
      end
      dputs 0, "#{course.inspect}"
    else
    import_old( lines )
    end
    course
  end
end



class Course < Entity
  attr_reader :diploma_dir
  
  def setup_instance
    if not self.students.class == Array
      self.students = []
    end
    @diploma_dir = @proxy.diploma_dir + "/#{self.name}"
    dputs 2, "Setting diploma_dir to #{@diploma_dir}"
  end

  def list_students
    dputs 3, "Students for #{self.name} are: #{self.students.inspect}"
    ret = []
    if self.students
      ret = self.students.collect{|s|
        if person = Entities.Persons.find_by_login_name( s )
          [ s, person.full_name ]
        end
      }
    end
    ret
  end

  def to_hash
    ret = super.clone
    ret.delete :students
    ret.merge :students => list_students
  end

  # Tests if we have everything necessary handy
  def export_check
    missing_data = []
    %w( start end sign duration teacher responsible description contents ).each{ |s|
      d = data_get s
      if not d or d.size == 0
        dputs 1, "Failed checking #{s}: #{d}"
      missing_data.push s
      end
    }
    return missing_data.size == 0 ? nil : missing_data
  end

  def date_fr( d, show_year = true )
    day, month, year = d.split('.')
    day = day.gsub( /^0/, '' )
    if day == "1"
      day = "1er"
    end
    month = %w( janvier février mars avril mai juin juillet août septembre octobre novembre décembre )[month.to_i-1]
    if show_year
      [ day, month, year ].join( " " )
    else
      [ day, month ].join( " " )
    end
  end

  def export_diploma
    return if export_check

    d_start, d_end, d_sign = data_get( %w( start end sign ) )
    same_year = 0
    [ d_start, d_end, d_sign ].each{|d|
      year = d.gsub( /.*\./, '' )
      if same_year == 0
      same_year = year
      elsif same_year != year
      same_year = false
      end
    }
    txt = <<-END
base_gestion
#{Entities.Persons.find_by_login_name( data_get :teacher ).full_name}
#{Entities.Persons.find_by_login_name( data_get :responsible ).full_name}
#{data_get :duration}
#{data_get :description}
#{data_get :contents}

#{date_fr(d_start, same_year)}
#{date_fr(d_end, same_year)}
#{date_fr(d_sign)}
END
    data_get( :students ).each{|s|
      grade = Entities.Grades.find_by_course_person( data_get( :course_id ), s )
      if grade
        txt += "#{grade} #{grade.student.full_name}\n" +
        "#{grade.remark}\n"
      end
    }
    dputs 2, "Text is: #{txt.gsub(/\n/, '*')}"
    txt
  end
  
  def get_pdfs
    if File::directory?( @diploma_dir )
      Dir::glob( "#{@diploma_dir}/*pdf" ).collect{|f| File::basename( f ) }.sort
    else
      []
    end
  end
end
