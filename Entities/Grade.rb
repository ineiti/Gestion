class Grades < Entities

  def setup_data
    value_entity_course :course
    value_entity_person :student
    value_int :random

    value_block :info
    value_list_int :means
    value_int :mean
    value_str :remark
  end

  def match_by_course_person(course, student)
    # dputs_func
    if course.class != Course
      course = Courses.match_by_course_id(course)
    end
    if student.class != Person
      student = Persons.match_by_login_name(student)
    end
    if course && student
      dputs(4) { "Found #{course.name} - #{student.login_name}" }
      grades = Grades.matches_by_course(course.course_id)
      grades.each { |g|
        dputs(4) { "Checking grade #{g.student}-#{g}-#{student}" }
        if g.student == student
          dputs(4) { "Found grade #{g} for #{student.login_name} in #{course.name}" }
          return g
        end
      }
    end
    return nil
  end

  def save_data(d)
    #dputs_func
    if not d.has_key? :grade_id
      id = matches_by_course(d[:course].course_id).select { |g|
        g.student == d[:student]
      }
      if id.length > 0
        dputs(2) { "Saving grade with existing id of #{id}" }
        d[:grade_id] = id[0].grade_id
      end
    end
    dputs(4) { "data is #{d.inspect}" }
    if d._means.count > 0
      d[:mean] = d[:means].reduce(:+) / d[:means].count
      dputs(4) { "data is #{d.inspect}" }
    else
      d._mean = 0
    end
    dputs(4) { "data before storing is #{d.inspect}" }
    super(d)
  end

  def self.grade_to_mean(g)
    case g
      when /P/ then
        10
      when /AB/ then
        13
      when /B/ then
        15
      when /TB/ then
        17
      when /E/ then
        19
      else
        9
    end
  end

  def migration_1_raw(g)
    course = Courses.match_by_course_id(g._course_id)
    if course and course.ctype
      g._means = [g._mean || 0] * course.ctype.tests_nbr.to_i
      dputs(4) { "means is #{g._means.inspect} - tests are #{course.ctype.tests_nbr.inspect}" }
    else
      dputs(0) { "Error: Migrating without ctype for #{g.inspect}..." }
      exit
    end
  end

  def migration_2_raw(g)
    g._course = g._course_id
    g._student = g._person_id
  end

  def self.create(data)
    grade = super(data)
    data._means and grade.means = data._means
    grade
  end
end

class Grade < Entity
  def setup_instance
    if ConfigBase.has_function? :course_server
      init_random
    end
  end

  def to_s
    begin
      value = (data_get(:mean).to_f * 2).round / 2
    rescue FloatDomainError => _e
      return 'NP'
    end

    case value
      when 10..11.5 then
        'P'
      when 12..13 then
        'AB'
      when 14..15.5 then
        'B'
      when 16..17.5 then
        'TB'
      when 18..20 then
        'E'
      else
        'NP'
    end
  end

  def mention
    case to_s
      when 'P' then
        'Passable'
      when 'AB' then
        'Assez bien'
      when 'B' then
        'Bien'
      when 'TB' then
        'Très bien'
      when 'E' then
        'Excellent'
      else
        'PAS PASSÉ'
    end
  end

  def init_random
    while not self.random
      r = rand(1_000_000_000).to_s.rjust(9, '0')
      Grades.match_by_random(r) or self.random = r
    end
  end

  def get_url_label
    # dputs_func
    init_random
    dputs(4) { "Course is #{course.inspect}" }
    center_id = course.center ? course.center.login_name : 'pit'
    dputs(4) { "Course is #{course.inspect}" }
    "#{ConfigBase.get_url(:label_url)}/#{center_id}/#{random}"
  end

  def person
    dputs(0) { "Error: Deprecated - use student in #{caller.inspect}" }
    student
  end

  def means=(m)
    if m != self._means
      if ConfigBase.has_function? :course_client
        self.random = nil
      end
    end
    if m
      self._means = m.collect { |v| [20.0, [0.0, v.to_f].max].min }
      self._mean = means.reduce(:+).to_f / m.count.to_f
    end
  end

  def remark=(r)
    if r != self._remark
      if ConfigBase.has_function? :course_client
        self.random = nil
      end
    end
    self._remark = r
  end
end
