# A course has:
# - Beginning, End and days of week
# - Person.Students
# - Teacher and Assistant
# - Classroom

require 'zip'
require 'zip/filesystem'
require 'docsplit'
require 'rqrcode'
require 'rqrcode/export/png'
require 'base64'


class Courses < Entities
  attr_reader :dir_diplomas, :dir_exas, :dir_exas_share,
              :print_presence, :print_presence_small, :print_exa, :print_exa_long

  def setup_data

    value_block :name
    value_entity_courseType_ro_all :ctype, :drop, :name
    value_str :name

    value_block :calendar
    value_date :start
    value_date :end
    value_date :sign
    value_int :duration
    value_list_drop :dow, '%w( lu-me-ve ma-je-sa lu-ve ma-sa )'
    value_list_drop :hours, '%w( 9-12 16-18 9-11 )'
    value_entity_room_all :classroom, :drop, :name

    value_block :students
    value_list :students

    value_block :teacher
    value_entity_person :teacher, :drop, :full_name
    value_entity_person_empty :assistant, :drop, :full_name
    value_entity_person :responsible, :drop, :full_name

    value_block :center
    value_entity_person_empty :center, :drop, :full_name,
                              lambda { |p| p.permissions.index('center') }

    value_block :content
    value_str :description
    value_text :contents

    value_block :accounting
    value_int :salary_teacher
    value_int :salary_assistant
    value_int :students_start
    value_int :students_finish
    value_int :cost_student
    value_int :entry_total

    value_block :account
    value_entity_account_empty :entries, :drop, :path

    @dir_diplomas ||= 'Diplomas'
    @dir_exas ||= 'Exas'
    @dir_exas_share ||= 'Exas/Share'

    [@dir_exas, @dir_exas_share].each { |d|
      File.exists? d or FileUtils.mkdir d
    }

    @thread = nil
    @presence_sheet ||= 'presence_sheet.ods'
    @presence_sheet_small ||= 'presence_sheet_small.ods'
    @print_presence = OpenPrint.new("#{@dir_diplomas}/#{@presence_sheet}")
    @print_presence_small = OpenPrint.new("#{@dir_diplomas}/#{@presence_sheet_small}")
    @print_exa = (1..3).collect { |i|
      OpenPrint.new("#{@dir_diplomas}/exa_#{i}.ods")
    }
    @print_exa_long = (1..3).collect { |i|
      OpenPrint.new("#{@dir_diplomas}/exa_#{i}_long.ods")
    }
  end

  def set_entry(id, field, value)
    case field.to_s
      when 'name'
        value.gsub!(/[^a-zA-Z0-9_-]/, '_')
    end
    super(id, field, value)
  end

  def sort_courses(c)
    c.collect { |d| [d.course_id, d.name] }.sort { |a, b|
      a[1].gsub(/.*([0-9]{4}.*)/, '\1') <=> b[1].gsub(/.*([0-9]{4}.*)/, '\1')
    }.reverse
  end

  def list_courses_raw(session=nil)
    ret = search_all_
    if session != nil
      user = session.owner
      if not session.can_view('FlagCourseGradeAll')
        ret = ret.select { |d|
          dputs(4) { "teacher is #{d.teacher.inspect}, user is #{user.inspect}" }
          (d.teacher and d.teacher.login_name == user.login_name) or
              (d.responsible and d.responsible.login_name == user.login_name) or
              ((d.name =~ /^#{session.owner.login_name}_/) and
                  session.owner.permissions.index('center'))
        }
      end
    end
    ret
  end

  def list_courses(session=nil)
    sort_courses(list_courses_raw(session))
  end

  def list_courses_entries(session=nil)
    sort_courses(list_courses_raw(session).select { |c| c.entries })
  end

  def list_courses_for_person(person)
    ln = person.class == String ? person : person.login_name
    dputs(3) { "Searching courses for person #{ln}" }
    ret = @data.values.select { |d|
      dputs(3) { "Searching #{ln} in #{d.inspect} - #{d[:students].index(ln)}" }
      d[:students] and d[:students].index(ln)
    }.collect { |c| Courses.match_by_course_id(c._course_id) }
    dputs(3) { "Found courses #{ret.inspect}" }
    sort_courses(ret)
  end

  def self.create_ctype(ctype, date, creator = nil)
    needs_center = (ConfigBase.has_function?(:course_server) and
        (creator and creator.has_permission?(:center)))
    dputs(4) { "needs_center is #{needs_center.inspect}" }

    # Prepare correct name
    name = if needs_center
             if creator.permissions.index 'center'
               creator.login_name
             else
               Persons.find_by_permissions(:center).login_name
             end + '_'
           else
             ''
           end + "#{ctype.name}_#{date}"

    # Check for double names
    suffix = ''
    counter = 1
    while Courses.match_by_name(name + suffix)
      counter += 1
      suffix = "-#{counter}"
    end
    name += suffix

    course = self.create(:name => name)
    course.data_set_hash(ctype.to_hash.except(:name), true).ctype = ctype

    if needs_center
      dputs(3) { "Got center of #{creator.inspect}" }
      course.center = creator
    end

    if ConfigBase.get_functions.index :accounting_courses
      course.create_account
    end

    course.salary_teacher = ctype.salary_teacher
    course.cost_student = ctype.cost_student

    log_msg :course, "Created new course #{course.inspect}"
    return course
  end

  def self.from_date_fr(str)
    day, month, year = str.split(' ')
    day = day.gsub(/^0/, '')
    if day == '1er'
      day = '1'
    end
    month = %w( janvier février mars avril mai juin juillet août
    septembre octobre novembre décembre ).index(month) + 1
    "#{day.to_s.rjust(2, '0')}.#{month.to_s.rjust(2, '0')}.#{year.to_s.rjust(4, '2000')}"
  end

  def self.from_diploma(course_name, course_str)
    dputs(1) { "Importing #{course_name}: #{course_str.gsub(/\n/, '*')}" }
    course = Entities.Courses.match_by_name(course_name) or
        Entities.Courses.create(:name => course_name)

    lines = course_str.split("\n")
    template = lines.shift
    dputs(2) { "Template is: #{template}" }
    dputs(2) { "lines are: #{lines.inspect}" }
    case template
      when /base_gestion/ then
        course.teacher, course.responsible = lines.shift(2).collect { |p|
          Entities.Persons.find_full_name(p)
        }
        if not course.teacher or not course.responsible then
          return nil
        end
        course.teacher, course.responsible = course.teacher.login_name, course.responsible.login_name
        course.duration, course.description = lines.shift(2)
        course.contents = ''
        while lines[0].size > 0
          course.contents += lines.shift
        end
        dputs(2) { "Course contents: #{course.contents}" }
        lines.shift
        course.start, course.end, course.sign =
            lines.shift(3).collect { |d| self.from_date_fr(d) }
        lines.shift if lines[0].size == 0

        course.students = []
        while lines.size > 0
          grade, name = lines.shift.split(' ', 2)
          student = Entities.Persons.find_name_or_create(name)
          course.students_add student
          g = Grades.match_by_course_person(course, student)
          if g then
            g.mean, g.remark = Grades.grade_to_mean(grade), lines.shift
          else
            Grades.create(:course => course, :student => student,
                          :mean => Grades.grade_to_mean(grade), :remark => lines.shift)
          end
        end
        dputs(3) { "#{course.inspect}" }
      else
        import_old(lines)
    end
    course
  end

  def migration_1(c)
    name = c.classroom
    if name.class == Array
      name = name.join
    end
    dputs(4) { "Converting for name #{name} with #{Rooms.data.inspect}" }
    r = Rooms.match_by_name(name)
    if (not r) and (not (r = Rooms.match_by_name('')))
      r = nil
    end
    c.classroom = r
    dputs(4) { "New room is #{c.classroom.inspect}" }
  end

  def migration_2_raw(c)
    %w( teacher assistant responsible ).each { |p|
      person = c[p.to_sym]
      dputs(4) { "#{p} is before #{person.inspect}" }
      if p == 'assistant' and person == ['none']
        person = nil
      else
        begin
          person = Persons.match_by_login_name(person.join).person_id
        rescue NoMethodError
          person = Persons.match_by_login_name('admin').person_id
        end
      end
      dputs(4) { "#{p} is after #{person.inspect}" }
      c[p.to_sym] = person
    }
  end

  def icc_users(tr)
    users = tr._data
    dputs(3) { "users are #{users.inspect}" }
    users.each { |s|
      s.to_sym!
      if s._login_name != tr._user
        s._login_name = "#{tr._user}_#{s._login_name}"
      else
        s.delete :password
      end
      %w( person_id groups ).each { |f|
        s.delete f.to_sym
      }
      s._permissions = if s._permissions
                         s._permissions & %w( teacher center )
                       else
                         dputs(0) { "User #{s._login_name} has no permissions!" }
                         []
                       end
      dputs(3) { "Person is #{s.inspect}" }
      dputs(4) { "Looking for #{s._login_name}" }
      if stud = Persons.match_by_login_name(s._login_name)
        dputs(3) { "Updating person #{stud.login_name} with #{s._login_name}" }
        stud.data_set_hash(s)
      else
        dputs(3) { "Creating person #{s.inspect}" }
        Persons.create(s)
      end
    }
    "Got users #{users.collect { |u| u._login_name }.join(':')}"
  end

  def center_course_name(course, user)
    course =~ /^#{user}_/ ? course : "#{user}_#{course}"
  end

  def icc_course(tr)
    course = tr._data.to_sym
    dputs(3) { "Course is #{course.inspect}" }
    course.delete :course_id
    course._name = center_course_name(course._name, tr._user)
    course._responsible = Persons.match_by_login_name(
        "#{tr._user}_#{course._responsible}")
    course._teacher = Persons.match_by_login_name(
        "#{tr._user}_#{course._teacher}")
    course._assistant = Persons.match_by_login_name(
        "#{tr._user}_#{course._assistant}")
    course._students = course._students.collect { |s| "#{tr._user}_#{s}" }
    course._ctype = CourseTypes.match_by_name(course._ctype)
    return "Error: couldn't make course of type #{course.ctype}" unless course._ctype
    course._center = Persons.match_by_login_name(tr._user)
    course._room = Rooms.find_by_name('')
    dputs(3) { "Course is now #{course.inspect}" }
    if c = Courses.match_by_name(course._name)
      dputs(3) { "Updating course #{course._name}" }
      c.data_set_hash(course)
    else
      dputs(3) { "Creating course #{course._name}" }
      Courses.create(course)
    end
    "Updated course #{course._name}"
  end

  def icc_grades(tr)
    tr._data.collect { |grade|
      grade.to_sym!
      ret = [grade._course, grade._student]
      dputs(3) { "Grades is #{grade.inspect}" }
      grade._course =
          Courses.match_by_name("#{tr._user}_#{grade._course}")
      grade._student =
          Persons.match_by_login_name("#{tr._user}_#{grade._student}")
      grade.delete :grade_id
      grade.delete :random
      if g = Grades.match_by_course_person(grade._course,
                                           grade._student)
        dputs(3) { "Updating grade #{g.inspect} with #{grade.inspect}" }
        g.data_set_hash(grade)
      else
        g = Grades.create(grade)
        dputs(3) { "Creating grade #{g.inspect} with #{grade.inspect}" }
      end
      dputs(3) { Grades.match_by_course_person(grade._course,
                                               grade._student).inspect }
      ret.push g.random
    }
  end

  def icc_exams(tr)
    tr._tid.gsub!(/[^a-zA-Z0-9_-]/, '')
    file = "/tmp/#{tr._tid}.zip"
    File.open(file, 'w') { |f| f.write Base64::decode64(tr._data._zip) }
    if course = Courses.match_by_name(center_course_name(tr._data._course, tr._user))
      dputs(3) { 'Updating exams' }
      course.zip_read(file)
    end
    "Read file #{file}"
  end

  def icc_exams_here(tr)
    course_name = center_course_name(tr._data, tr._user)
    if course = Courses.match_by_name(course_name)
      dputs(3) { "Sending md5 of #{course_name}" }
      course.md5_exams
    else
      dputs(3) { "Didn't find #{course_name}" }
      {}
    end
  end

end


class Course < Entity
  attr_reader :sync_state, :make_pdfs_state
  attr :thread

  def setup_instance
    if not self.students.class == Array
      self.students = []
    end

    check_students_dir
    @make_pdfs_state = {'0' => 'undefined'}
    @only_psnup = false
  end

  def update_state
    if @make_pdfs_state['0'] == 'undefined'
      @make_pdfs_state = {}
      students.collect { |s|
        dputs(3) { "Working on #{s}" }
        Persons.match_by_login_name(s)
      }.compact.each { |s|
        get_grade_args(s, true)
      }
      @make_pdfs_state['0'] = 'done'
    end
  end

  def check_dir
    [dir_diplomas, dir_exas, dir_exas_share].each { |d|
      (!File.exists? d) and FileUtils.mkdir_p(d)
    }
  end

  def check_students_dir
    check_dir
    students and students.each { |s|
      [dir_exas, dir_exas_share].each { |d|
        (!File.exists? "#{d}/#{s}") and FileUtils.mkdir("#{d}/#{s}")
      }
    }
  end

  def dir_diplomas
    @proxy.dir_diplomas + "/#{self.name}"
  end

  def dir_exas
    @proxy.dir_exas + "/#{self.name}"
  end

  def dir_exas_share
    @proxy.dir_exas_share + "/#{self.name}"
  end

  def list_students(by_id = false)
    dputs(3) { "Students for #{self.name} are: #{self.students.inspect}" }
    ret = []
    if self.students
      ret = self.students.collect { |s|
        if person = Persons.match_by_login_name(s)
          [(by_id ? person.person_id : s),
           "#{person.full_name} - #{person.login_name}:#{person.password_plain}"]
        end
      }.select { |s| s }.sort { |a, b| a[1] <=> b[1] }
    end
    ret
  end

  def to_hash(unique_ids = false)
    ret = super(unique_ids).clone
    ret.delete :students
    ret.merge :students => list_students
  end

  # Tests if we have everything necessary handy
  def export_check
    missing_data = []
    %w( start end sign duration teacher responsible description contents ).each { |s|
      d = data_get s
      if not d
        dputs(1) { "Failed checking #{s}: #{d}" }
        missing_data.push s
      end
    }
    return missing_data.size == 0 ? nil : missing_data
  end

  def date_fr(d, show_year = true)
    day, month, year = d.split('.')
    day = day.gsub(/^0/, '')
    if day == '1'
      day = '1er'
    end
    month = %w( janvier février mars avril mai juin juillet août septembre octobre novembre décembre )[month.to_i-1]
    if show_year
      [day, month, year].join(' ')
    else
      [day, month].join(' ')
    end
  end

  def date_en(d, show_year = true)
    day, month, year = d.split('.')
    day = day.gsub(/^0/, '')
    day_str = case day.to_i
                when 1,21,31
                  "#{day}st"
                when 2,22
                  "#{day}nd"
                when 3,23
                  "#{day}rd"
                when 4..20,24..30
                  "#{day}th"
              end
    month = %w( January February March April May June July August September October November December )[month.to_i-1]
    if show_year
      "#{day_str} of #{month}, #{year}"
    else
      "#{day_str} of #{month}"
    end
  end

  def date_i18n(d, show_year = true)
    case ctype.diploma_lang.first
      when /en/
        date_en( d, show_year)
      when /fr/
        date_fr(d, show_year)
      else
        dputs(0){"Unknown date type #{ctype.diploma_lang.inspect}"}
    end
  end

  def export_diploma
    return if export_check

    d_start, d_end, d_sign = data_get(%w( start end sign ))
    same_year = 0
    [d_start, d_end, d_sign].each { |d|
      year = d.gsub(/.*\./, '')
      if same_year == 0
        same_year = year
      elsif same_year != year
        same_year = false
      end
    }
    txt = <<-END
base_gestion
#{teacher.full_name}
    #{responsible.full_name}
    #{duration}
    #{description}
    #{contents}

    #{date_fr(d_start, same_year)}
    #{date_fr(d_end, same_year)}
    #{date_fr(d_sign)}
    END
    students.each { |s|
      grade = Grades.match_by_course_person(course_id, s)
      if grade
        txt += "#{grade} #{grade.student.full_name}\n" +
            "#{grade.remark}\n"
      end
    }
    dputs(2) { "Text is: #{txt.gsub(/\n/, '*')}" }
    txt
  end

  def get_files
    if File::directory?(dir_diplomas)
      files = if ctype.output[0] == 'certificate'
                Dir::glob("#{dir_diplomas}/*pdf")
              else
                Dir::glob("#{dir_diplomas}/*png") +
                    Dir::glob("#{dir_diplomas}/*zip")
              end
      files.collect { |f|
        File::basename(f)
      }.sort
    else
      []
    end
  end

  def dstart
    Date.strptime(start, '%d.%m.%Y')
  end

  def dend
    Date.strptime(data_get(:end), '%d.%m.%Y')
  end

  def get_duration_adds
    return [0, 0] if not start or not data_get(:end)
    dputs(4) { "start is: #{start} - end is #{data_get(:end)} - dow is #{dow}" }
    days_per_week, adds = case dow.to_s
                            when /lu-me-ve/, /ma-je-sa/
                              [3, [0, 2, 4]]
                            when /lu-ve/, /ma-sa/
                              [5, [0, 1, 2, 3, 4]]
                          end
    weeks = ((dend - dstart) / 7).ceil
    day = 0
    dow_adds = (0...weeks).collect { |w| adds.collect { |a|
      day += 1
      [/#{1000 + day}/, a + w * 7]
    }
    }.flatten(1)
    dputs(4) { "dow_adds is now #{dow_adds.inspect}" }

    [days_per_week * weeks, dow_adds]
  end

  def print_presence(lp_cmd = nil)
    return false if not teacher
    return false if not start or not data_get(:end) or students.count == 0
    stud_nr = 1
    studs = students.sort { |a, b|
      Persons.match_by_login_name(a).full_name <=>
          Persons.match_by_login_name(b).full_name }.collect { |s|
      stud = Entities.Persons.match_by_login_name(s)
      stud_str = stud_nr.to_s.rjust(2, '0')
      stud_nr += 1
      [[/Nom#{stud_str}/, stud.full_name],
       [/Login#{stud_str}/, stud.login_name],
       [/Passe#{stud_str}/, stud.password_plain]]
    }
    dputs(3) { "Students are: #{studs.inspect}" }
    duration, dow_adds = get_duration_adds

    pp = if duration <= 25 and stud_nr <= 16
           @proxy.print_presence_small
         else
           @proxy.print_presence
         end
    lp_cmd and pp.lp_cmd = lp_cmd
    pp.print(studs.flatten(1) + dow_adds + [
                 [/Teacher/, teacher.full_name],
                 [/Course_name/, name],
                 [/2010-08-20/, dstart.to_s],
                 [/20.08.10/, dstart.strftime('%d/%m/%y')],
                 [/2010-10-20/, dend.to_s],
                 [/20.10.10/, dend.strftime('%d/%m/%y')],
                 [/123/, students.count],
                 [/321/, duration],
             ])
  end

  def print_exa(lp_cmd, number)
    if !self.start || !self.end
      return false
    end
    stud_nr = 1
    studs = students.collect { |s|
      Entities.Persons.match_by_login_name(s)
    }.sort_by { |s| s.full_name }.collect { |stud|
      stud_str = stud_nr.to_s.rjust(2, '0')
      stud_nr += 1
      [[/Nom#{stud_str}/, stud.full_name],
       [/Login#{stud_str}/, stud.login_name],
       [/Passe#{stud_str}/, stud.password_plain]]
    }
    (stud_nr..30).each { |s|
      studs.push [[/Nom#{s.to_s.rjust(2, '0')}/, '']]
    }
    ddputs(3) { "#{stud_nr}: Students are: #{studs.inspect}" }

    pp = if stud_nr - 1 <= 12
           @proxy.print_exa[number - 1]
         else
           @proxy.print_exa_long[number - 1]
         end

    pp.lp_cmd = lp_cmd
    pp.print(studs.flatten(1) + [
                 [/Teacher/, teacher.full_name],
                 [/Course_name/, name],
                 [/Center_name/, center.full_name],
                 [/2010-08-20/, dstart.to_s],
                 [/20.08.10/, dstart.strftime('%d/%m/%y')],
                 [/2010-10-20/, dend.to_s],
                 [/20.10.10/, dend.strftime('%d/%m/%y')],
                 [/123/, students.count],
                 [/321/, duration],
             ])
  end

  def get_grade_args(student, update = false)
    grade = Grades.match_by_course_person(course_id, student)
    dputs(3) { "Course is #{name} - student is #{student} - ctype is #{ctype.inspect} and grade is " +
        "#{grade.inspect} - #{grade.to_s}" }

    state = if (ctype.diploma_type[0] == 'accredited') && grade &&
        (!grade.random)
              'not synched'
            elsif exam_files(student).count < ctype.files_nbr.to_i
              'incomplete'
            elsif (not grade) or (grade.to_s == 'NP')
              'not passed'
            elsif update
              if get_files.find { |f| f =~ /^[0-9]+-#{student.login_name}\./ }
                'done'
              else
                'not created'
              end
            else
              'queued'
            end
    mean = if grade and grade.mean
             grade.mean
           else
             '-'
           end
    dputs(4) { "State is #{state}" }
    ln = student.login_name
    @make_pdfs_state[ln] = [mean, state, get_diploma_filename(ln, 'pdf', false)]

    [grade, state]
  end

  def update_student_diploma(file, student)
    #dputs_func
    grade, state = get_grade_args(student)

    #if grade and grade.to_s != "NP" and
    #    ( ( ctype.diploma_type[0] == "simple" ) or
    #      ( exam_files( student ).count >= ctype.files_nbr.to_i ) ) and
    #    ( ( ctype.diploma_type[0] == "accredited" ) and grade.random )
    #  @make_pdfs_state[student.login_name] = [ grade.mean, "queued" ]
    if state != 'queued'
      FileUtils.rm(file)
    else
      dputs(3) { "New diploma for: #{course_id} - #{student.login_name} - #{grade.to_hash.inspect}" }
      Zip::File.open(file) { |z|
        dputs(5) { "Cours is #{self.inspect}" }
        doc = z.read('content.xml')
        doc.force_encoding(Encoding::UTF_8)
        dputs(5) { doc.inspect }
        dputs(5) { "Contents is: #{contents.inspect}" }
        if qrcode = /draw:image.*xlink:href="([^"]*).*QRcode.*\/draw:frame/.match(doc)
          dputs(2) { "QRcode-image is #{qrcode[1]}" }
          qr = RQRCode::QRCode.new(grade.get_url_label)
          png = qr.as_png(:border_modules => 0)
          z.get_output_stream(qrcode[1]) { |f|
            png.write(f)
          }
        end

        cont = contents +
            (grade.remark.to_s.length > 0 ? "\n#{grade.remark}" : '')
        if desc_p_match = /-DESC1-(.*)-DESC2-/.match(doc)
          desc_p = desc_p_match[1]
          dputs(3) { "desc_p is #{desc_p}" }
          doc.gsub!(/-DESC1-.*-DESC2-/,
                    cont.split("\n").join(desc_p))
        end
        doc.gsub!(/-TEACHER-/, teacher.full_name)
        role_diploma = 'Enseignant informatique'
        if teacher.role_diploma.to_s.length > 0
          role_diploma = teacher.role_diploma
        end
        doc.gsub!(/-TEACHER_ROLE-/, role_diploma)
        role_diploma = 'Responsable informatique'
        if responsible.role_diploma.to_s.length > 0
          role_diploma = responsible.role_diploma
        end
        doc.gsub!(/-RESP_ROLE-/, role_diploma)
        doc.gsub!(/-RESP-/, responsible.full_name)
        doc.gsub!(/-NAME-/, student.full_name)
        doc.gsub!(/-DURATION-/, duration.to_s)
        doc.gsub!(/-COURSE-/, description)
        doc.gsub!(/-COURSE_ID-/, name)
        show_year = start.gsub(/.*\./, '') != self.end.gsub(/.*\./, '')
        doc.gsub!(/-SPECIAL-/, '')
        doc.gsub!(/-GRADE-/, grade.mention)
        doc.gsub!(/-DATE-/, date_i18n(sign))
        doc.gsub!(/-FROM-/, date_i18n(start, show_year))
        doc.gsub!(/-TO-/, date_i18n(self.end))
        doc.gsub!(/-COURSE_TYPE-/, ctype.name)
        doc.gsub!(/-URL_LABEL-/, grade.get_url_label)
        c = center
        doc.gsub!(/-CENTER_NAME-/, c.full_name)
        doc.gsub!(/-CENTER_ADDRESS-/, c.address || '')
        doc.gsub!(/-CENTER_PLACE-/, c.town || '')
        doc.gsub!(/-CENTER_PHONE-/, c.phone || '')
        doc.gsub!(/-CENTER_EMAIL-/, c.email || '')

        dputs(3) { "ctype is #{ctype.inspect}" }
        if ctype.diploma_type.first =~ /report/
          dputs(3) { 'Adding report-lines' }
          if test_p_match = /-TEST1-(.*)-MEAN1-(.*)-TEST2-/.match(doc)
            test_p = test_p_match[1..2]
            dputs(3) { "test_p is #{test_p.inspect}" }
            if grade.means.count == ctype.tests_arr.count
              tests = ctype.tests_arr.zip(grade.means).collect { |t, m|
                t + test_p[0] + m.to_s
              }.join(test_p[1])
              doc.gsub!(/-TEST1-.*-MEAN2-/, tests)
            else
              dputs(1) { "Incomplete tests for #{student.login_name}" }
            end
          end
        end
        doc.gsub!(/-MEAN-/, grade.mean.to_s)
        doc.gsub!(/(number-rows-spanned=)\"3\"/, "\\1\"#{ctype.tests_nbr+1}\"")
        z.get_output_stream('content.xml') { |f|
          f.write(doc)
        }
        z.commit
      }
    end
  end

  def get_diploma_filename(student, ext = 'odt', diplomadir = true)
    digits = students.size.to_s.size
    counter = students.index(student) + 1
    str = diplomadir ? dir_diplomas : name
    "#{str}/#{counter.to_s.rjust(digits, '0')}-#{student}.#{ext}"
  end

  def make_pdfs(convert)
    if @thread
      dputs(2) { 'Thread is here, killing' }
      begin
        abort_pdfs
      rescue Exception => e
        dputs(0) { "Error while killing: #{e.message}" }
        dputs(0) { "#{e.inspect}" }
        dputs(0) { "#{e.to_s}" }
        puts e.backtrace
      end
    end

    dputs(2) { 'Starting new thread' }
    @thread = Thread.new {
      begin
        counter = 1
        dputs(2) { "Preparing students: #{students.inspect}" }
        if !@only_psnup
          students.sort.each { |s|
            student = Persons.match_by_login_name(s)
            if student
              dputs(4) { "Is #{s} == #{student.login_name}?" }
              student_file = get_diploma_filename(s)
              dputs(2) { "Doing #{counter}: #{s} - file: #{student_file}" }
              FileUtils.cp("#{Courses.dir_diplomas}/#{ctype.filename.join}",
                           student_file)
              update_student_diploma(student_file, student)
            end
            counter += 1
          }
        end

        dputs(3) { "Convert is #{convert.inspect}" }
        if convert
          @make_pdfs_state['0'] = 'converting'
          old = Dir.glob(dir_diplomas + '/content.xml*')
          list = Dir.glob(dir_diplomas + '/*odt')
          format = ctype.output[0].to_sym

          dputs(4) { "old is #{old.inspect}" }
          dputs(4) { "list is #{list.inspect}" }

          FileUtils.rm(old)
          if list.size == 0
            dputs(2) { 'No files here, quitting' }
            @make_pdfs_state['0'] = 'done'
            @thread.kill
          end
          dputs(2) { "Creating -#{format.inspect}-#{list.inspect}-" }
          `date >> /tmp/cp`
          %x[ ls -l #{dir_diplomas} >> /tmp/cp ]
          outfiles = []
          dir = File::dirname(list.first)
          @only_psnup and list = []
          list.sort.each { |p|
            dputs(3) { "Started thread for file #{p} in directory #{dir}" }
            student_name = p.sub(/.*[0-9]+-/, '').sub(/\.odt/, '')
            dputs(3) { "Student name is #{student_name}" }
            @make_pdfs_state[student_name][1] = 'working'

            if format == :certificate
              Docsplit.extract_pdf p, :output => dir
            else
              Docsplit.extract_images p, :output => dir,
                                      :density => 300, :format => :png
              FileUtils.mv(p.sub(/.odt$/, '_1.png'), p.sub(/.odt$/, '.png'))
            end
            dputs(5) { 'Finished docsplit' }
            FileUtils.rm(p)
            dputs(5) { 'Finished rm' }
            outfile = p.sub(/\.[^\.]*$/, format == :certificate ? '.pdf' : '.png')
            outfiles.push outfile
            @make_pdfs_state[student_name][1] = 'done'
            @make_pdfs_state[student_name][2] = outfile.sub(/^#{@proxy.dir_diplomas}./, '')
          }
          @make_pdfs_state['0'] = 'collecting'
          if format == :certificate
            dputs(3) { "Getting #{outfiles.inspect} out of #{dir}" }
            all = "#{dir}/000-all.pdf"
            psn = "#{dir}/000-4pp.pdf"
            #cmd = "pdftk #{outfiles.join( ' ' )} cat output #{all}"
            if outfiles.length > 1
              cmd = "pdfunite #{outfiles.join(' ')} #{all}"
              dputs(3) { "Putting it all in one file: #{cmd}" }
              %x[ #{cmd} ]
            else
              dputs(3) { "#{outfiles.first} - #{all}" }
              FileUtils.cp(outfiles.first, all)
            end
            dputs(3) { "Putting 4 pages of #{all} into #{psn}" }
            pf = ctype.data_get(:page_format, true)[0]
            format = ['', '-f', '-l', '-r'][pf - 1]
            dputs(3) { "Page-format is #{pf.inspect}: #{format}" }
            `pdftops #{all} - | psnup -4 #{format} | ps2pdf -sPAPERSIZE=a4 - #{psn}.tmp`
            FileUtils.mv("#{psn}.tmp", psn)
            dputs(2) { 'Finished' }
          else
            dputs(3) { 'Making a zip-file' }
            Zip::File.open("#{dir}/all.zip", Zip::File::CREATE) { |z|
              Dir.glob("#{dir}/*").each { |image|
                z.get_output_stream(image.sub('.*/', '')) { |f|
                  File.open(image) { |fi|
                    f.write fi.read
                  }
                }
              }
            }
          end
        end
      rescue Exception => e
        dputs(0) { "Error in thread: #{e.message}" }
        dputs(0) { "#{e.inspect}" }
        dputs(0) { "#{e.to_s}" }
        puts e.backtrace
      end
      @make_pdfs_state['0'] = 'done'
    }
  end

  def prepare_diplomas(convert = true)
    dputs(2) { "dir_diplomas is: #{dir_diplomas}" }
    if not File::directory? dir_diplomas
      FileUtils.mkdir(dir_diplomas)
    else
      if !@only_psnup
        FileUtils.rm_rf(Dir.glob(dir_diplomas + '/*'))
      end
    end
    @make_pdfs_state = {'0' => 'collecting'}
    #@make_pdfs_state = {}
    make_pdfs(convert)
  end

  # This prepares a zip-file as a skeleton for the center to copy the
  # files over.
  # The name of the zip-file is different from the directory-name, so that the
  # upload is less error-prone.
  # @param [Object] for_server
  # @param [Object] include_files
  # @param [Object] md5sums
  # @param [Object] users
  def zip_create(for_server: true, include_files: true, md5sums: {},
                 size_exams: -1, files_added: nil)
    pre = for_server ? center.login_name + '_' : ''
    dir = "exa-#{pre}#{name}"
    file = "#{pre}#{name}.zip"
    tmp_file = "/tmp/#{file}"
    dputs(2) { "for_server:#{for_server} - include_files:#{include_files} " +
        "md5sums:#{md5sums.inspect} - size_exams:#{size_exams.inspect}" }

    if students and students.size > 0
      File.exists?(tmp_file) and FileUtils.rm(tmp_file)
      Zip::File.open(tmp_file, Zip::File::CREATE) { |z|
        z.mkdir dir
        dputs(3) { "Students is #{students.inspect}" }
        files_excluded = []
        students.sort.each { |s|
          p = "#{dir}/#{pre}#{s}"
          dputs(3) { "Creating #{p}" }
          z.mkdir(p)
          if include_files
            dputs(3) { "Searching in #{dir_exas}/#{s}" }
            Dir.glob("#{dir_exas}/#{s}/*").sort.each { |exa_f|
              exa_md5 = Digest::MD5.file(exa_f).hexdigest
              file_add = true
              filename = exa_f.sub(/.*\//, '')
              if md5sums.has_key?(s)
                md5sums[s].each { |f, md5|
                  if (f == filename) && (md5 == exa_md5)
                    dputs(3) { "Found file #{filename} to be excluded" }
                    file_add = false
                    files_excluded.push exa_f.sub(/^#{dir_exas}\//, '')
                  end
                }
              end
              if file_add and size_exams != 0
                dputs(3) { "Adding file #{exa_f} with size #{size_exams}" }
                files_added and files_added.push [s, File.basename(exa_f), exa_md5]
                z.file.open("#{p}/#{exa_f.sub(/.*\//, '')}", 'w') { |f|
                  f.write File.open(exa_f) { |ef|
                            content = ef.read
                            dputs(3) { "Size of file is #{content.size}" }
                            size_exams -= [content.size, size_exams.abs].min
                            content
                          }
                }
              end
            }
          end
        }
        dputs(3) { "Files_excluded are #{files_excluded.inspect}" }
        z.file.open("#{dir}/files_excluded", 'w') { |f|
          f.write files_excluded.to_json
        }
      }
      return file
    end
    return nil
  end

  def zip_read(f = nil)
    name.length == 0 and return

    dir_zip = "exa-#{name.sub(/^#{center}_/, '')}"
    dir_exas = @proxy.dir_exas + "/#{name}"
    dir_exas_tmp = "/tmp/#{name}"
    file = f || "/tmp/#{dir_zip}.zip"
    dputs(3) { "dir_zip: #{dir_zip}, dir_exas: #{dir_exas}, dir_exas_tmp: #{dir_exas_tmp}, " +
        "file: #{file}" }

    if File.exists?(file) && students
      # Save existing exams in /tmp
      FileUtils.rm_rf dir_exas_tmp
      if File.exists? dir_exas
        dputs(3) { "Moving #{dir_exas} to /tmp" }
        dputs(3) { "#{dir_exas} is " + Dir.glob("#{dir_exas}/**/*").join(' ') }
        FileUtils.mv dir_exas, dir_exas_tmp
      end
      FileUtils.mkdir dir_exas

      dputs(3) { "Opening zip-file #{file}" }
      Zip::File.open(file) { |z|
        students.each { |s|
          dir_zip_student = "#{dir_zip}/#{s}"
          dir_exas_student = "#{dir_exas}/#{s}"

          begin
            FileUtils.mkdir(dir_exas_student)
            if (files_student = z.dir.entries(dir_zip_student)).size > 0
              files_student.each { |fs|
                dputs(3) { "Extracting #{dir_exas_student}/#{fs}" }
                z.extract("#{dir_zip_student}/#{fs}", "#{dir_exas_student}/#{fs}")
              }
            end
          rescue Errno::ENOENT => e
            dputs(3) { "Directory for student #{s} doesn't exist" }
          end
        }
        begin
          center_pre = ConfigBase.has_function?(:course_server) ?
              "#{center.login_name}_" : ''
          JSON.parse(z.read("#{dir_zip}/files_excluded")).each { |f|
            dputs(3) { "Transferring file #{f} from old to new directory" }
            FileUtils.cp "#{dir_exas_tmp}/#{center_pre + f}",
                         "#{dir_exas}/#{center_pre + f}"
          }
        rescue Errno::ENOENT => e
          dputs(3) { 'No files_excluded here' }
        end
      }
      FileUtils.rm file
    end
  end

  def exam_files(student)
    student_name = student.class == Person ? student.login_name : student
    dputs(4) { "Student-name is #{student_name.inspect}" }
    dir_exas = @proxy.dir_exas + "/#{name}"
    dir_student = "#{dir_exas}/#{student_name}"
    File.exists?(dir_student) ?
        Dir.entries(dir_student).select { |f| !(f =~ /^\./) } : []
  end

  def exas_prepare_files
    name.length == 0 and return
    if File.exists? dir_exas_share
      %x[ rm -rf #{dir_exas_share} ]
    end

    FileUtils.mkdir dir_exas_share
    students.each { |s|
      dir_s_exas = "#{dir_exas}/#{s}"
      if File.exists? dir_s_exas
        FileUtils.mv dir_s_exas, dir_exas_share
      else
        FileUtils.mkdir "#{dir_exas_share}/#{s}"
      end
    }
    %x[ rm -rf #{dir_exas} ]
  end

  def exas_fetch_files
    name.length == 0 and return
    dputs(3) { "Starting to fetch files for #{name}" }
    if File.exists? dir_exas_share
      dputs(3) { "#{dir_exas_share} exists" }
      File.exists? dir_exas or FileUtils.mkdir dir_exas
      students.each { |s|
        dputs(3) { "Checking on student #{s}" }
        dir_student = "#{dir_exas_share}/#{s}"
        if File.exists? dir_student
          dputs(3) { "Moving student-dir of #{s}" }
          FileUtils.move dir_student, "#{dir_exas}"
        end
      }
    end
    %x[ rm -rf #{dir_exas_share} ]
  end

  def sync_transfer(field, transfer = '', json = true)
    ss = @sync_state
    ret = ICC.transfer(Persons.center, "Courses.#{field}", transfer,
                       url: ConfigBase.get_url(:server_url), json: json) { |s|
      @sync_state = "#{ss} #{s}" }
    @sync_state = ss
    ret
  end

  def sync_do
    @sync_state = sync_s = ''
    dputs(3) { @sync_state }

    dputs(4) { 'Responsibles' }
    @sync_state = sync_s += '<li>Transferring responsibles: '
    users = [teacher, responsible, center, assistant].compact.collect { |n| n.login_name }
    ret = sync_transfer(:users, users.collect { |s|
                                Persons.match_by_login_name(s)
                              }.compact)
    if ret._code == 'Error'
      @sync_state += "Error: #{ret._msg}"
      dputs(2) { "Error is #{ret._msg}" }
      return false
    end
    @sync_state = sync_s += 'OK</li>'

    dputs(4) { 'Students' }
    if students.length > 0
      dputs(4) { 'Students - go' }
      @sync_state = sync_s += '<li>Transferring users: '
      users = students + [teacher.login_name, responsible.login_name]
      ret = sync_transfer(:users, users.collect { |s|
                                  Persons.match_by_login_name(s)
                                })
      if ret._code == 'Error'
        @sync_state += "Error: #{ret._msg}"
        return false
      end
      @sync_state = sync_s += 'OK</li>'
    end

    dputs(4) { 'Courses' }
    @sync_state = sync_s += '<li>Transferring course: '
    myself = self.to_hash(true)
    myself._students = students
    ret = sync_transfer(:course, myself)
    if ret._code == 'Error'
      @sync_state += "Error: #{ret._msg}"
      return false
    end
    @sync_state = sync_s += 'OK</li>'

    dputs(4) { 'Grades' }
    if (grades = Grades.matches_by_course(self.course_id)).length > 0
      dputs(4) { 'Grades - go' }
      @sync_state = sync_s += '<li>Transferring grades: '
      ret = sync_transfer(:grades, grades.select { |g|
                                   g.course and g.student
                                 }.collect { |g|
                                   dputs(4) { "Found grade with #{g.course.inspect} and #{g.student.inspect}" }
                                   g.to_hash(true).merge(:course => g.course.name,
                                                         :person => g.student.login_name)
                                 })
      if ret._code == 'Error'
        @sync_state += "Error: #{ret._msg}"
        return false
      end
      grades = ret._msg
      #grades = JSON.parse(ret.sub(/^OK: /, ''))
      dputs(3) { "Return is #{grades.inspect}" }
      grades.each { |g|
        course_name, student, random = g
        course = Courses.match_by_name(course_name)
        if grade = Grades.match_by_course_person(course, student)
          dputs(4) { "Setting grade-random of #{grade.grade_id} to #{random}" }
          grade.random = random
        else
          dputs(0) { "Error: Can't find grade for #{course}-#{student}!" }
        end
      }
      @sync_state = sync_s += 'OK</li>'
    end

    dputs(4) { 'Exams' }
    remote_exams = {}
    if true
      dputs(4) { 'Fetching remote exams' }
      @sync_state = sync_s += '<li>Demander ce qui existe déjà: '
      ret = sync_transfer(:exams_here, self.name)
      if ret._code == 'Error'
        @sync_state += "Error: #{ret._msg}"
        return false
      end
      remote_exams = ret._msg
      @sync_state = sync_s += 'OK</li>'
    end

    local_exams = md5_exams
    files = zip_create_chunks(local_exams, remote_exams)
    files.each { |file|
      dputs(4) { 'Exams - go' }
      @sync_state = sync_s + '<li>Transferring exams ' +
          "#{files.index(file) + 1}/#{files.count}: "
      file = "/tmp/#{file}"
      dputs(3) { "Exa-file is #{file}" }
      file_64 = Base64::encode64(File.open(file) { |f| f.read }.
                                     force_encoding(Encoding::ASCII_8BIT))
      ret = sync_transfer(:exams, {zip: file_64, course: name})
      if ret._code == 'Error'
        @sync_state += "Error: #{ret._msg}"
        return false
      end
    }
    @sync_state = sync_s += '<li>Transferring exams: OK</li>'

    @sync_state = sync_s += 'It is finished!'
    dputs(3) { @sync_state }
    return true
  end

  def sort_md5s(m)
    m.map { |k, v| {k => v.sort { |a, b| a[0] <=> b[0] }} }
  end

  def zip_create_chunks(local, remote)
    files = []
    loop {
      fa = []
      dputs(3) { "Remote: #{remote.inspect}" }
      dputs(3) { "Local: #{local.inspect}" }
      zipfile = zip_create(md5sums: remote, size_exams: ConfigBase.max_upload_size.to_i,
                           files_added: fa)
      fa.length == 0 and return files

      zipfile_cnt = "#{zipfile.chomp('.zip')}-#{files.size}.zip"
      FileUtils.mv "/tmp/#{zipfile}", "/tmp/#{zipfile_cnt}"
      files.push zipfile_cnt
      dputs(3) { "Zip-file #{files.last} has files added #{fa.inspect}" }
      fa.each { |s, f, md5|
        dputs(3) { "Found student #{s} with file #{f} and md5 #{md5} in zip" }
        remote[s] ||= []
        remote[s].push [f, md5]
      }
    }
    []
  end

  def sync_start
    if @thread
      dputs(2) { 'Thread is here, killing' }
      begin
        abort_pdfs
      rescue Exception => e
        dputs(0) { "Error while killing: #{e.message}" }
        dputs(0) { "#{e.inspect}" }
        dputs(0) { "#{e.to_s}" }
        puts e.backtrace
      end
    end
    dputs(2) { 'Starting new thread' }
    @sync_state = 'Starting'
    @thread = Thread.new {
      begin
        sync_do
      rescue Exception => e
        dputs(0) { "Error in thread: #{e.message}" }
        dputs(0) { "#{e.inspect}" }
        dputs(0) { "#{e.to_s}" }
        puts e.backtrace
        @sync_state += "Error: thread reported #{e.to_s}"
      end
    }
  end

  def get_unique
    name
  end

  def center
    dputs(4) { ".center is #{_center.inspect}" }
    dputs(4) { "Persons.center is #{Persons.find_by_permissions(:center).inspect}" }
    ret = _center || Persons.find_by_permissions(:center)
    dputs(4) { "Center is #{ret.login_name}" }
    ret
  end

  def abort_pdfs
    if @thread
      dputs(3) { "Killing thread #{@thread}" }
      @thread.kill
      @thread.join
      dputs(3) { 'Joined thread' }
    end
  end

  def delete
    abort_pdfs

    [dir_diplomas, dir_exas, dir_exas_share].each { |d|
      FileUtils.remove_entry_secure(d, true)
    }
    super
  end

  def students=(s)
    self._students = s
    @pre_init or log_msg :course, "Students for #{name} are: #{students.inspect}"
  end

  def students_add(studs)
    [studs].flatten.each { |s|
      s.class == Person and s = s.login_name
      log_msg :course, "Adding student #{s} to course #{name}"
      self.students = (students || []) + [s]
    }
  end

  def students_del(studs)
    [studs].flatten.each { |s|
      s.class == Person and s = s.login_name
      log_msg :course, "Deleting student #{s} to course #{name}"
      self.students = (students || []) - [s]
    }
  end

  def report_pdf
    file = "/tmp/course_#{name}.pdf"
    Prawn::Document.generate(file,
                             :page_size => 'A4',
                             :page_layout => :portrait,
                             :bottom_margin => 2.cm) do |pdf|

      sum = 0
      pdf.text "Report for #{name} (#{ctype.name})",
               :align => :center, :size => 20
      pdf.font_size 10
      pdf.text "Duration: #{start}-#{self.end} - - Teacher: #{teacher.full_name}" +
                   " - - Hours: #{hours}"
      pdf.text "Cost per student: #{Account.total_form(cost_student.to_i / 1000)} - - " +
                   "Cost per teacher: #{Account.total_form(salary_teacher.to_i / 1000)}"
      pdf.text "Account: #{entries.path}"
      pdf.move_down 1.cm

      if students.length > 0
        pdf.table([['Description', 'Value', 'Sum'].collect { |ch|
                     {:content => ch, :align => :center} }] +
                      report_list.collect { |id, t|
                        [t[0] == 'Reste' ? t[1] : t[0],
                         t[2],
                         t[3]]
                      },
                  :header => true, :column_widths => [300, 75, 75])
        pdf.move_down(2.cm)
      end

      pdf.repeat(:all, :dynamic => true) do
        pdf.draw_text "#{Date.today} - #{entries.path}",
                      :at => [0, -20], :size => 10
        pdf.draw_text pdf.page_number, :at => [18.cm, -20]
      end
    end
    file
  end

  def student_paid(student)
    movs = entries.movements
    if archives = entries.get_archives
      movs.concat archives.collect { |a| a.movements }.flatten
    end

    movs.select { |e| e.desc =~ / #{student}:/ }
  end

  def student_payments(student)
    total = 0
    movs = entries.movements
    if archives = entries.get_archives
      movs.concat archives.collect { |a| a.movements }.flatten
    end

    movs.reverse.select { |e| e.desc =~ / #{student}:/ }.collect { |e|
      total += e.value
      [e.global_id,
       [e.date, e.value_form, '']]
    } + [[nil,
          ['Reste', Account.total_form(total),
           Account.total_form(cost_student.to_f / 1000 - total)]]]
  end

  def report_list
    entries or return []
    movs = entries.movements
    if archives = entries.get_archives
      movs.concat archives.collect { |a| a.movements }.flatten
    end

    students.sort { |a, b|
      Persons.match_by_login_name(a).full_name <=>
          Persons.match_by_login_name(b).full_name }.collect { |s|
      total = 0
      (movs.select { |e| e.desc =~ / #{s}:/ }.collect { |e|
        total += e.value
        [e.global_id,
         [e.date,
          '',
          e.value_form,
          ''
         ]] } +
          [[nil,
            ['Reste',
             "#{Persons.match_by_login_name(s).full_name} (#{s})",
             Account.total_form(total),
             Account.total_form(cost_student.to_f / 1000 - total)
            ]]]).reverse
    }.flatten(1)
  end

  def create_account
    if ctype.account_base
      self.entries = Accounts.create_path(
          "#{ctype.account_base.path}::#{name}")
    else
      dputs(1) { "Trying to create account for #{name} but " +
          " #{ctype.name} has no base-account" }
    end
  end

  def payment(secretary, student, amount, date = Date.today, oldcash = false)
    log_msg :course_payment, "#{secretary.full_login} got #{amount} " +
                               "of #{student.full_name} in #{name}"
    Movements.create("For student #{student.login_name}:" +
                         "#{student.full_name}",
                     date.strftime('%Y-%m-%d'), amount.to_f / 1000,
                     secretary.account_due, entries)
    if secretary.has_permission?(:admin) && oldcash
      log_msg 'course-payment', 'Oldcash - doing reverse, too'
      Movements.create("old_cash for #{student.login_name}",
                       date.strftime('%Y-%m-%d'), amount.to_f / 1000,
                       entries, secretary.account_due)
    end
  end

  def transfer_student(student, new_course)
    return if !students.index(student)
    return if !new_course.entries
    return if new_course.students.index(student)

    log_msg 'course', "Transferring #{student} from #{name} to #{new_course.name}"
    self.students = students - [student]
    new_course.students_add student

    entries.movements.select { |m|
      m.desc =~ / #{student}:/
    }.each { |m|
      other = m.get_other_account(entries)
      if other.get_path =~ /::Paid$/
        Movements.create("Transfert of student #{student}:",
                         m.date, m.get_value(entries), entries, new_course.entries)
      else
        value = m.get_value(entries)
        m.value = 0
        m.account_dst_id = new_course.entries
        m.value = value
      end
    }
  end

  def move_payment(src, dst)
    return if !students.index(src)
    return if !students.index(dst)

    log_msg :Course, "Transferring payments from #{src} to #{dst}"

    movs = entries.movements
    if archives = entries.get_archives
      movs.concat archives.collect { |a| a.movements }.flatten
    end

    p_dst = Persons.match_by_login_name(dst)
    p_src = Persons.match_by_login_name(src)
    src_dst = "#{p_src.login_name}-#{p_src.full_name} to " +
        "#{p_dst.login_name}-#{p_dst.full_name}"
    movs.select { |m|
      m.desc =~ / #{src}:/
    }.each { |m|
      other = m.get_other_account(entries)
      if other.get_path =~ /::Paid$/ ||
          other.get_path =~ /^Archive::/
        value = m.get_value(entries)
        m.desc = "Moved payment from #{src_dst}"
        Movements.create("Moved payment from #{src_dst}",
                         m.date, value, entries, other)
        Movements.create("For student #{dst}:#{p_dst.full_name}",
                         m.date, value, other, entries)
      else
        m.desc = "For student #{dst}:#{p_dst.full_name}"
      end
    }
  end

  def md5_exams
    center_pre = ConfigBase.has_function?(:course_server) ?
        "#{center.login_name}_" : ''
    dputs(3) { "Fetching existing files with center -#{center_pre}-" }
    Hash[students.map { |s|
           [s.sub(/^#{center_pre}/, ''),
            Dir.glob("#{dir_exas}/#{s}/*").map { |exa_f|
              md5 = Digest::MD5.file(exa_f).hexdigest
              exa_rel = exa_f.sub(/^.*\//, '')
              dputs(3) { "Adding file #{exa_rel} with md5 #{md5}" }
              [exa_rel, md5]
            }]
         }]
  end

  def rename(new_name)
    log_msg :Courses, "Renaming #{name} to #{new_name}"
    dir = "#{@proxy.dir_exas}/#{name}"
    if File.exists?(dir)
      log_msg :Courses, "Moving files of #{name} to #{new_name}"
      FileUtils.mv dir, "#{@proxy.dir_exas}/#{new_name}"
    end
    self.name = new_name
    if entries
      entries.name = new_name
    end
  end

end
