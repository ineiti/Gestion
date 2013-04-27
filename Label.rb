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
        if ( user = Persons.find_by_login_name( d._user ) ) and
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
      center = grade.course.responsible.full_name
      ERB.new( File.open("Files/label.erb"){|f|f.read}).result(binding)
    else
      ERB.new( File.open("Files/label_notfound.erb"){|f|f.read}).result(binding)
    end
  end
  {:field=>"start", :data=>"{\"md5\":\"693b255477353c9aec0412e48c0fc415\",
\"tid\":\"ec6f22c26aa808d90226c30fc94f1599\",\"chunks\":7,\"field\":\"grades\",
\"pass\":\"1234\",\"user\":\"foo\"}"}
  def self.field_save( tr )
    course_name = "#{tr._user}_#{tr._course}"
    ddputs(3){"Course-name is #{course_name} and field is #{tr._field}"}
    case tr._field
    when /students/
      students = JSON.parse( tr._data )
    when /grades/
      grades = JSON.parse( tr._data )
    when /exams/
      file = "/tmp/#{tr._tid}.zip"
      File.open(file, "w"){|f| f.write tr._data }
      if course = Courses.find_by_name( course_name )
        course.zip_read( file )
      end
    end
  end
end