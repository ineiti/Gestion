# This works togehter with UploadMgr to retrieve files.
require 'erb'

class Label < RPCQooxdooPath
  @@transfers = {}

  def self.parse_req(req)
    dputs(4) { "Label: #{req.inspect}" }
    if req.request_method == 'POST'
      dputs(0){ 'Deprecated' }
      exit
      path, query, addr = req.path, req.query.to_sym, RPCQooxdooHandler.get_ip(req)
      dputs(4) { "Got query: #{path} - #{query.inspect} - #{addr}" }

      if query._field == 'start'
        log_msg :label, "Got start-query: #{path} - #{query.inspect} - #{addr}"
        d = JSON.parse(query._data).to_sym
        dputs(3) { "d is #{d.inspect}" }
        if (user = Persons.match_by_login_name(d._user)) and
            (user.check_pass(d._pass))
          @@transfers[d._tid] = d.merge(:data => '')
          return 'OK: send field'
        else
          dputs(3) { "User #{d._user.inspect} with pass #{d._pass.inspect} unknown" }
          return 'Error: authentification'
        end
      elsif @@transfers.has_key? query._field
        tr = @@transfers[query._field]
        dputs(3) { "Found transfer-id #{query._field}, #{tr._chunks} left" }
        tr._data += query._data
        if (tr._chunks -= 1) == 0
          if Digest::MD5.hexdigest(tr._data) == tr._md5
            dputs(2) { "Successfully received field #{tr._field}" }
            ret = self.field_save(tr)
          else
            dputs(2) { "Field #{tr._field} transmitted with errors" }
            ret = 'Error: wrong MD5'
          end
          @@transfers.delete query._field
          return ret
        else
          return "OK: send #{tr._chunks} more chunks"
        end
      end
      return 'Error: must start or use existing field'
    else
      path = /.*\/([^\/]*)\/([^\/]*)$/.match(req.path)
      dputs(3) { "Path is #{path.inspect}" }
      log_msg :label, "Got label-query: #{path.inspect}"
      self.get_student(path[1], path[2])
    end
  end

  def self.get_student(center, grade_id)
    dputs(3) { "Printing student #{grade_id} of #{center}" }
    if grade = Grades.match_by_random(grade_id)
      dputs(3) { "Grade is #{grade.inspect}" }
      center_short = grade.course.name.sub(/_.*/, '')
      dputs(3) { "Center_short is #{center_short}" }
      center = center_short
      if center_person = Persons.match_by_login_name(center_short)
        center = center_person.full_name
      end
      remark = if grade.remark
                 if grade.remark =~ /^http:\/\//
                   "Site web: <a href='#{grade.remark}'>#{grade.remark}</a>"
                 else
                   "Remarques: #{grade.remark}"
                 end
               else
                 ''
               end
      log_msg :show_grade, "Student #{grade.student.full_name} from #{center} in course #{grade.course.name} " +
          "has grade #{grade.mean}"
      if grade.mean >= 10
        ERB.new(File.open('Files/label.erb') { |f| f.read }).result(binding)
      else
        ERB.new(File.open('Files/label_notpassed.erb') { |f| f.read }).result(binding)
      end
    else
      log_msg :show_grade, "Unknown grade-id #{grade_id}"
      ERB.new(File.open('Files/label_notfound.erb') { |f| f.read }).result(binding)
    end
  end

  def self.field_save(tr)
    dputs(0){ 'Deprecated'}
    exit

    if not (course_name = tr._course) =~ /^#{tr._user}_/
      course_name = "#{tr._user}_#{tr._course}"
    end
    dputs(3) { "Course-name is #{course_name} and field is #{tr._field}" }
    case tr._field
      when 'users'
        users = JSON.parse(tr._data)
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
          s._permissions = s._permissions & %w( teacher center )
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
        "OK: Got users #{users.collect { |u| u._login_name }.join(':')}"
      when 'course'
        course = JSON.parse(tr._data).to_sym
        dputs(3) { "Course is #{course.inspect}" }
        course.delete :course_id
        course._name = "#{course_name}"
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
        course._room = Rooms.find_by_name("")
        dputs(3) { "Course is now #{course.inspect}" }
        if c = Courses.match_by_name(course._name)
          dputs(3) { "Updating course #{course._name}" }
          c.data_set_hash(course)
        else
          dputs(3) { "Creating course #{course._name}" }
          Courses.create(course)
        end
        "OK: Updated course #{course._name}"
      when 'grades'
        'OK: ' + JSON.parse(tr._data).collect { |grade|
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
        }.to_json
      when 'exams'
        tr._tid.gsub!(/[^a-zA-Z0-9_-]/, '')
        file = "/tmp/#{tr._tid}.zip"
        File.open(file, 'w') { |f| f.write tr._data }
        if course = Courses.match_by_name(course_name)
          dputs(3) { 'Updating exams' }
          course.zip_read(file)
        end
        "OK: Read file #{file}"
      when 'exams_here'
        'OK: ' + if course = Courses.match_by_name(course_name)
                   dputs(3) { "Sending md5 of #{course_name}" }
                   course.md5_exams
                 else
                   dputs(3) { "Didn't find #{course_name}" }
                   {}
                 end.to_json
    end
  end
end
