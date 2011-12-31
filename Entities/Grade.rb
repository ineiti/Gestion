class Grades < Entities
  
  def setup_data
    value_int :course_id
    value_int :person_id
    
    value_block :info
    value_int :mean
    value_str :remark
  end
  
  def find_by_course_person( course_id, person_login_name )
    course = Entities.Courses.find_by_course_id( course_id )
    student = Entities.Persons.find_by_login_name( person_login_name )
    if course and student
      dputs 3, "Found #{course} and #{student}"
      grades = Entities.Grades.search_by_course_id( course.course_id )
      grades.each{|g|
        dputs 4, "Checking grade #{g}"
        if g.person_id.to_i == student.person_id.to_i
          dputs 2, "Found grade #{g}"
          g.set_course_student( course, student )
          return g
        end
      }
    end
    return nil
  end
  
  def save_data( d )
    if not d.has_key? :grade_id
      id = search_by_course_id( d[:course_id]).select{|g|
        g.person_id == d[:person_id]
      }
      if id.length > 0
        dputs 2, "Saving grade with existing id of #{id}"
        d[:grade_id] = id[0].grade_id
      end
    end
    super( d )
  end
  
  def self.grade_to_mean( g )
    case g
    when /P/ then 10
    when /AB/ then 13
    when /B/ then 15
    when /TB/ then 17
    when /E/ then 19
    else
    9
    end
  end
end

class Grade < Entity
  attr_reader :course, :student
  
  def to_s
    case data_get( :mean ).to_i
    when 10..11 then "P"
    when 12..14 then "AB"
    when 15..16 then "B"
    when 17..18 then "TB"
    when 19..20 then "E"
    else "NP"
    end
  end
  
  def mention
    case data_get( :mean ).to_i
    when 10..11 then "Passable"
    when 12..14 then "Assez bien"
    when 15..16 then "Bien"
    when 17..18 then "Très bien"
    when 19..20 then "Excellent"
    else "PAS PASSÉ"
    end
  end

  def set_course_student( c, s )
    @course, @student = c, s
  end
end
