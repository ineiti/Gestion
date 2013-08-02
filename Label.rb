# This works togehter with UploadMgr to retrieve files.
require 'erb'

class Label < RPCQooxdooPath
  @@transfers = {}
  def self.parse_req( req )
    dputs( 4 ){ "Label: #{req.inspect}" }
    if req.request_method == "POST"
      #self.parse( req.request_method, req.path, req.query, req.peeraddr[2] )
      path, query, addr = req.path, req.query.to_sym, req.peeraddr[2]
      dputs(4){"Got query: #{path} - #{query.inspect} - #{addr}"}
      
      if query._field == "start"
        d = JSON.parse( query._data ).to_sym
        dputs(3){"d is #{d.inspect}"}
        if ( user = Persons.match_by_login_name( d._user ) ) and
            ( user.check_pass( d._pass ) )
          @@transfers[d._tid] = d.merge( :data => "" )
          return "OK: send field"
        else
          dputs(3){"User #{d._user.inspect} with pass #{d._pass.inspect} unknown"}
          return "Error: authentification"
        end
      elsif @@transfers.has_key? query._field
        tr = @@transfers[query._field]
        dputs(3){"Found transfer-id #{query._field}, #{tr._chunks} left"}
        tr._data += query._data
        if ( tr._chunks -= 1 ) == 0
          if Digest::MD5.hexdigest( tr._data ) == tr._md5
            dputs(2){"Successfully received field #{tr._field}"}
            ret = "OK: #{self.field_save( tr )}"
          else
            dputs(2){"Field #{tr._field} transmitted with errors"}
            ret = "Error: wrong MD5"
          end
          @@transfers.delete query._field
          return ret
        else
          return "OK: send #{tr._chunks} more chunks"
        end
      end
      return "Error: must start or use existing field"
    else
      path = /.*\/([^\/]*)\/([^\/]*)$/.match( req.path )
      dputs(3){"Path is #{path.inspect}"}
      self.get_student( path[1], path[2] )
    end
  end

  def self.get_student( center, grade_id )
    dputs(3){"Printing student #{grade_id} of #{center}"}
    if grade = Grades.match_by_random( grade_id )
      center_short = grade.course.name.sub(/_.*/, '' )
      dputs(3){"Center_short is #{center_short}"}
      center = center_short
      if center_person = Persons.match_by_login_name( center_short )
        center = center_person.full_name
      end
      remark = if grade.remark
        if grade.remark =~ /^http:\/\//
          "Site web: <a href='#{grade.remark}'>#{grade.remark}</a>"
        else
          "Avec mention: #{grade.remark}"
        end
      else
        ""
      end
      ERB.new( File.open("Files/label.erb"){|f|f.read}).result(binding)
    else
      ERB.new( File.open("Files/label_notfound.erb"){|f|f.read}).result(binding)
    end
  end

  def self.field_save( tr )
    course_name = "#{tr._user}_#{tr._course}"
    dputs(3){"Course-name is #{course_name} and field is #{tr._field}"}
    case tr._field
    when /users/
      users = JSON.parse( tr._data )
      dputs(3){"users are #{users.inspect}"}
      users.each{|s|
        s.to_sym!
        if s._login_name != tr._user
          s._login_name = "#{tr._user}_#{s._login_name}"
        else
          s.delete :password
        end
        %w( person_id permissions groups ).each{|f|
          s.delete f.to_sym
        }
        dputs(3){"Person is #{s.inspect}"}
        dputs(4){"Looking for #{s._login_name}"}
        if stud = Persons.match_by_login_name( s._login_name )
          dputs(3){"Updating person #{stud.login_name} with #{s._login_name}"}
          stud.data_set_hash( s )
        else
          dputs(3){"Creating person #{s.inspect}"}
          Persons.create( s )
        end
      }
    when /course/
      course = JSON.parse( tr._data ).to_sym
      dputs(3){"Course is #{course.inspect}"}
      course.delete :course_id
      course._name = "#{course_name}"
      course._responsible = Persons.match_by_login_name( 
        "#{tr._user}_#{course._responsible}" )
      course._teacher = Persons.match_by_login_name( 
        "#{tr._user}_#{course._teacher}" )
      course._students = course._students.collect{|s| "#{tr._user}_#{s}"}
      course._ctype = CourseTypes.match_by_name( course._ctype )
      course._center = Persons.match_by_login_name( tr._user )
      dputs(3){"Course is now #{course.inspect}"}
      if c = Courses.match_by_name( course._name )
        dputs(3){"Updating course #{course._name}"}
        c.data_set_hash( course )
      else
        dputs(3){"Creating course #{course._name}"}
        Courses.create( course )
      end
    when /grades/
      JSON.parse( tr._data ).collect{|grade|
        grade.to_sym!
        ret = [ grade._course, grade._student ]
        dputs(3){"Grades is #{grade.inspect}"}
        grade._course = 
          Courses.match_by_name( "#{tr._user}_#{grade._course}" )
        grade._student = 
          Persons.match_by_login_name( "#{tr._user}_#{grade._student}" )
        grade.delete :grade_id
        grade.delete :random
        if g = Grades.match_by_course_person( grade._course, 
            grade._student )
          dputs(3){"Updating grade #{g.inspect} with #{grade.inspect}"}
          g.data_set_hash( grade )
        else
          g = Grades.create( grade )
          dputs(3){"Creating grade #{g.inspect} with #{grade.inspect}"}
        end
        dputs(3){Grades.match_by_course_person( grade._course, 
            grade._student ).inspect }
        ret.push g.random
      }.to_json
    when /exams/
      file = "/tmp/#{tr._tid}.zip"
      File.open(file, "w"){|f| f.write tr._data }
      if course = Courses.match_by_name( course_name )
        dputs(3){"Updating exams"}
        course.zip_read( file )
      end
    end
  end
end
