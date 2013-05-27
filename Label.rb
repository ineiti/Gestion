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
        ddputs(3){"d is #{d.inspect}"}
        if ( user = Persons.match_by_login_name( d._user ) ) and
            ( user.check_pass( d._pass ) )
          @@transfers[d._tid] = d.merge( :data => "" )
        else
          ddputs(3){"User #{d._user.inspect} with pass #{d._pass.inspect} unknown"}
        end
      elsif @@transfers.has_key? query._field
        tr = @@transfers[query._field]
        ddputs(3){"Found transfer-id #{query._field}, #{tr._chunks} left"}
        tr._data += query._data
        if ( tr._chunks -= 1 ) == 0
          if Digest::MD5.hexdigest( tr._data ) == tr._md5
            ddputs(2){"Successfully received field #{tr._field}"}
            self.field_save( tr )
          else
            ddputs(2){"Field #{tr._field} transmitted with errors"}
          end
          @@transfers.delete query._field
        end
      end
    else
      path = /\/label\/([^\/]*)\/([^\/]*).*/.match( req.path )
      self.get_student( path[1], path[2] )
    end
  end

  def self.get_student( center, grade_id )
    ddputs(3){"Printing student #{grade_id} of #{center}"}
    if grade = Grades.find_by_random( grade_id )
      center_short = grade.course.name.sub(/_.*/, '' )
      ddputs(3){"Center_short is #{center_short}"}
      center = center_short
      if center_person = Persons.match_by_login_name( center_short )
        center = center_person.full_name
      end
      ERB.new( File.open("Files/label.erb"){|f|f.read}).result(binding)
    else
      ERB.new( File.open("Files/label_notfound.erb"){|f|f.read}).result(binding)
    end
  end

  def self.field_save( tr )
    course_name = "#{tr._user}_#{tr._course}"
    ddputs(3){"Course-name is #{course_name} and field is #{tr._field}"}
    case tr._field
    when /students/
      students = JSON.parse( tr._data )
      ddputs(3){"Students are #{students.inspect}"}
      students.each{|s|
        s.to_sym!
        s._login_name = "#{tr._user}_#{s._login_name}"
        s.delete :person_id
        ddputs(4){"Looking for #{s._login_name}"}
        if stud = Persons.find_by_login_name( s._login_name )
          ddputs(3){"Updating person"}
          #stud.data_set_hash( s )
        else
          ddputs(3){"Creating person #{s.inspect}"}
          Persons.create( s )
        end
        dputs(0){"****** Foo is #{Persons.match_by_login_name('foo').inspect}"}
      }
    when /course/
      course = JSON.parse( tr._data ).to_sym
      ddputs(3){"Course is #{course.inspect}"}
      course.delete :course_id
      course._name = "#{tr._user}#{course_name}"
      course._responsible = Persons.find_by_login_name( 
        "#{tr._user}_#{course._responsible}" )
      course._teacher = Persons.find_by_login_name( 
        "#{tr._user}_#{course._teacher}" )
      course._students = course._students.collect{|s| "#{tr._user}_#{s}"}
      course._ctype = CourseTypes.find_by_name( course._ctype )
      course._center = tr._user
      ddputs(3){"Course is now #{course.inspect}"}
      if c = Courses.find_by_name( course._name )
        ddputs(3){"Updating course #{course._name}"}
        c.data_set_hash( course )
      else
        ddputs(3){"Creating course #{course._name}"}
        Courses.create( course )
      end
    when /grades/
      JSON.parse( tr._data ).each{|grade|
        grade.to_sym!
        ddputs(3){"Grades is #{grade.inspect}"}
        grade._course_id = 
          Courses.find_by_name( "#{tr._user}_#{grade._course}" ).course_id
        grade._person_id = 
          Persons.find_by_login_name( "#{tr._user}_#{grade._person}" ).person_id
        grade.delete :grade_id
        if g = Grades.find_by_course_person( grade._course_id, 
            "#{tr._user}_#{grade._person}" )
          ddputs(3){"Updating grade #{g.inspect}"}
          g.data_set_hash( grade )
        else
          g = Grades.create( grade )
          ddputs(3){"Creating grade #{g.inspect}"}
        end
        ddputs(3){Grades.find_by_course_person( grade._course_id, 
            "#{tr._user}_#{grade._person}" ).inspect }
      }
    when /exams/
      file = "/tmp/#{tr._tid}.zip"
      File.open(file, "w"){|f| f.write tr._data }
      if course = Courses.find_by_name( course_name )
        ddputs(3){"Updating exams"}
        course.zip_read( file )
      end
    end
  end
end
