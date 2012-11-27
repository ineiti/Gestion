# Used for returning some information about the internal state
# SHOULD NOT CHANGE ANYTHING IN HERE, JUST READING, INFORMATION!

class Info < RPCQooxdooPath
  def self.parse_req( req )
    dputs( 4 ){ "in QVInfo: #{req.inspect}" }
    self.parse( req.request_method, req.path, req.query, req.peeraddr[2] )
  end

  def self.parse( m, p, q, ip )
    dputs( 2 ){ "in QVInfo: #{m.inspect} - #{p} - #{q.inspect} - #{ip}" }
    method = p.gsub( /^.info./, '' )
    dputs( 3 ){ "Calling method #{method}" }
    self.send( method, q.to_sym, ip )
  end

  def self.date(args)
    dputs( 3 ){ "Arguments are: #{args.inspect}" }
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
    dputs( 3 ){ "Can #{args} do it?" }
    username = args[:user]
    user = Entities.Persons.match_by_login_name( username )[0]
    Internet.free( user ) ? "yes" : "no"
  end
  
  def self.isAllowed( args )
    dputs(3){"isAllowed for #{args.inspect}"}
    return "yes"
  end
  
  def self.login( args, ip )
    dputs(3){"Logging in with #{args.inspect}"}
    user = Persons.match_by_login_name( args[:user] )[0]
    if self.autoConnect( args ) == "yes"
      dputs(2){"Connecting user #{user.login_name} with ip #{ip}"}
      Internet.connect_user( ip, user.login_name )
      return "connected"
    end
    return "nothing"
  end
  
  def self.clientUse( args )
    dputs(3){"Client use with #{args.inspect}"}
    user = Persons.match_by_login_name( args[:user] )[0]
    if user
      if Internet.free( user )
        return "nopay"
      elsif user.groups and user.groups.index('localonly')
        return "local"
      elsif user.credit
        return user.credit
      end
    end
    return 0
  end

  def self.autoConnect( args )
    dputs(3){"AutoConnecting for #{args.inspect}"}
    user = Persons.match_by_login_name( args[:user] )[0]
    if user 
      case self.clientUse( args )
      when /local/
        return "no"
      else
        return "yes"
      end
    end    
    return "no"
  end
    
  def self.query( args, ip )
    dputs(3){"Querying with #{args.inspect}"}
    case args[:action]
    when /isAllowed/
      return self.isAllowed( args )
    when /login/
      return self.login( args, ip )
    when /clientUse/
      return self.clientUse( args )
    when /autoConnect/
      return self.autoConnect( args )
    end
  end
end
