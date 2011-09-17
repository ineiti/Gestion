# Used for returning some information about the internal state
# SHOULD NOT CHANGE ANYTHING IN HERE, JUST READING, INFORMATION!

class QVInfo
  def self.date(args)
    dputs 3, "Arguments are: #{args.inspect}"
    return Time.new.to_s
  end
  
  # We allow login for everybody. Things to do:
  # Check on room (info1, info2, others), course and time
  def self.allowed_login(args)
    username = args[:user]
    return "yes"
  end
  
  # Who is allowed to use internet for free?
  # For the moment everybody in a course that didn't end yet
  def self.internet_free(args)
    dputs 3, "Can #{args} do it?"
    username = args[:user]
    user = Entities.Persons.find_by_login_name( args[:user] )
    if user
      # We want an exact match, so we put the name between ^ and $
      courses = Entities.Courses.search_by_students( "^#{user.login_name}$" )
      if courses
        dputs 0, "Courses"
        courses.each{|c|
	  dputs 0, [ c.name, c.start, c.end ].inspect
	  begin
	    c_start = Date.strptime( c.start, "%d.%m.%Y" )
	    c_end = Date.strptime( c.end, "%d.%m.%Y" )
	  rescue
	    c_start = c_end = Date.new
	  end
	  if c_start <= Date.today and Date.today <= c_end
	    return "yes"
	  end
	}
      end
    end
    return "no"
  end
end

class RPCQooxdooHandler
  def self.parse_info( p, q )
    dputs 0, "in QVInfo: #{p} - #{q.inspect}"
    method = p.gsub( /^.info./, '' )
    dputs 3, "Calling method #{method}"
    QVInfo.send( method, q.to_sym )
  end
end
