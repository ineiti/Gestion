class Grades < Entities
  
  def setup_data
    value_int :course_id
    value_int :person_id
    value_int :random
    
    value_block :info
    value_list_int :means
    value_int :mean
    value_str :remark
  end
  
  def match_by_course_person( course_id, person_login_name )
    course = Entities.Courses.match_by_course_id( course_id )
    student = Entities.Persons.match_by_login_name( person_login_name )
    if course and student
      dputs( 3 ){ "Found #{course} and #{student}" }
      grades = Entities.Grades.search_by_course_id( course.course_id )
      grades.each{|g|
        dputs( 4 ){ "Checking grade #{g}" }
        if g.person_id.to_i == student.person_id.to_i
          dputs( 2 ){ "Found grade #{g}" }
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
        dputs( 2 ){ "Saving grade with existing id of #{id}" }
        d[:grade_id] = id[0].grade_id
      end
    end
    dputs(4){"data is #{d.inspect}"}
    d[:mean] = d[:means].reduce(:+) / d[:means].count
    dputs(4){"data is #{d.inspect}"}
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
  
  def migration_1(g)
    course = Courses.match_by_course_id( g.course_id )
    if course.ctype
      g.means = [ g.mean || 0 ] * course.ctype.tests.to_i
      dputs(4){"means is #{g.means.inspect} - tests are #{course.ctype.tests.inspect}"}
    else
      dputs(0){"Migrating without ctype for #{g.inspect}..."}
      exit
    end
  end
end

class Grade < Entity
  def setup_instance
    init_random
  end
  
  def to_s
    value = ( data_get( :mean ).to_f * 2 ).round / 2
    case value
    when 10..11.5 then "P"
    when 12..14 then "AB"
    when 14.5..16.5 then "B"
    when 17..18.5 then "TB"
    when 19..20 then "E"
    else "NP"
    end
  end
  
  def mention
    case to_s
    when "P" then "Passable"
    when "AB" then "Assez bien"
    when "B" then "Bien"
    when "TB" then "Très bien"
    when "E" then "Excellent"
    else "PAS PASSÉ"
    end
  end
  
  def init_random
    while not self.random
      r = rand( 1_000_000_000 ).to_s.rjust( 9, "0" )
      Grades.match_by_random( r ) or self.random = r
    end
  end
  
  def get_url_label
    init_random
    dputs(4){"Course is #{course.inspect}"}
    center_id = course.center ? course.center.login_name : "pit"
    dputs(4){"Course is #{course.inspect}"}
    "#{course.ctype.get_url}/#{center_id}/#{random}"
  end
  
  def course
    Courses.match_by_course_id( course_id )
  end
  
  def person
    Persons.match_by_person_id( person_id )
  end
  
  def student
    person
  end
end
