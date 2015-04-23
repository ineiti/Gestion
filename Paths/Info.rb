# Used for returning some information about the internal state
# SHOULD NOT CHANGE ANYTHING IN HERE, JUST READING, INFORMATION!

class Info < RPCQooxdooPath
  def self.parse_req( req )
    dputs( 4 ){ "in QVInfo: #{req.inspect}" }
    self.parse( req.request_method, req.path, req.query, RPCQooxdooHandler.get_ip( req ) )
  end

  def self.parse( m, p, q, ip )
    dputs( 2 ){ "in QVInfo: #{m.inspect} - #{p} - #{q.inspect} - #{ip}" }
    method = p.gsub( /^.info./, '' )
    dputs( 3 ){ "Calling method #{method}" }
    if self.respond_to? method.to_sym
      self.send( method, q.to_sym, ip )
    else
      dputs(0){ "Error: method #{method} not in Info" }
      ''
    end
  end

  def self.date(args)
    dputs( 3 ){ "Arguments are: #{args.inspect}" }
    return Time.new.to_s
  end
  
  # We allow login for everybody. Things to do:
  # Check on room (info1, info2, others), course and time
  def self.allowed_login(args)
    username = args[:user]
    return 'yes'
  end
  
  # Who is allowed to use internet for free?
  # For the moment everybody in a course that didn't end yet
  def self.internet_free(args)
    dputs( 3 ){ "Can #{args} do it?" }
    username = args[:user]
    user = Entities.Persons.match_by_login_name( username )
    Internet.free( user ) ? 'yes' : 'no'
  end
  
  def self.isAllowed( args, ip )
    dputs(3){"isAllowed for #{args.inspect} in #{ip}"}
    return "yes"
  end
  
  def self.login( args, ip )
    dputs(3){"Logging in with #{args.inspect}"}
    user = Persons.match_by_login_name( args[:user] )
    if self.autoConnect( args, ip ) == 'yes'
      dputs(2){"Auto-connecting user #{user.login_name} with ip #{ip}"}
      Internet.user_connect( user.login_name, ip )
      return 'connected'
    end
    return 'nothing'
  end

  def self.clientUse( args, ip )
    #return "nopay"
    dputs(3){"Client use with #{args.inspect}"}
    user = Persons.match_by_login_name( args[:user] )
    if user
      dputs(3){"Found user with groups #{user.groups.inspect} and internet_credit #{user.internet_credit.inspect}"}
      if Internet.free( user )
        dputs(3){ 'Found free' }
        return 'nopay'
      elsif user.groups and user.groups.index('localonly')
        dputs(3){ 'Found localonly' }
        return 'local'
      elsif user.internet_credit
        dputs(3){"Credit is #{user.internet_credit.inspect}"}
        return user.internet_credit
      end
    end
    return 0
  end

  def self.autoConnect( args, ip )
    #return "yes"
    dputs(3){"AutoConnecting for #{args.inspect}"}
    user = Persons.match_by_login_name( args[:user] )
    if user 
      cu = self.clientUse( args, ip )
      cost_max = Operator.user_cost_max
      dputs(4){ "clientUse is #{cu.inspect} - cost_max is #{cost_max.inspect}" }
      case cu
      when /nopay/
        return 'yes'
      when /local/
        return 'no'
      when -100...cost_max
        return 'no'
      else
        return 'yes'
      end
    end    
    return 'no'
  end
    
  def self.query( args, ip )
    dputs(3){"Querying with #{args.inspect}"}
    case args[:action]
    when /isAllowed/
      return self.isAllowed( args, ip )
    when /login/
      return self.login( args, ip )
    when /clientUse/
      return self.clientUse( args, ip )
    when /autoConnect/
      return self.autoConnect( args, ip )
    end
  end
end
