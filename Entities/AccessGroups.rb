# Defines groups for access to the internet

class AccessGroups < Entities
  def setup_data
    value_str :name
    value_list_single :members
    value_list_drop :action, "%w( allow allow_else_block block )"
    value_int :priority
    value_int :limit_day_mo
    value_list_single :access_times, "[]"
  end
  
  def listp_name
    search_all.sort{|a,b|
      b.priority.to_i <=> a.priority.to_i
    }.collect{|ag|
      ag.priority ||= "10"
      [ag.accessgroup_id, "#{ag.priority.rjust(2,'0')}:#{ag.name}"]
    }
  end
  
  def self.allow_user( user, time )
    dputs(4){"Searching for #{user} at #{time}"}
    if user.class == Person
      user = user.login_name
    end
    search_all().sort{|a,b| 
      b.priority.to_i <=> a.priority.to_i 
    }.each{|ag|
      match_user = true
      if ag.members.class == Array and ag.members.size > 0
        dputs(5){"members.index is #{ag.members.index(user).inspect}"}
        match_user = ag.members.index( user ) != nil
      end
      match_time = ag.time_in_atimes( time )
      limit_ok = true
      if ( limit = ag.limit_day_mo.to_i ) > 0
        limit_ok = $lib_net.call( nil, :USAGE_DAILY ).to_i / 1e6 <= limit
      end
      dputs(4){"Checking #{ag.name}, u,t = #{match_user},#{match_time}"}
      dputs(4){"Action is #{ag.action[0].inspect}, members = #{ag.members.inspect}"}
      case ag.action[0]
      when /allow_else_block/
        dputs(4){"allow_else_block"}
        return [true, "#{ag.name}"] if ( match_time and match_user and limit_ok )
        return [false, "Over limit of #{ag.limit_day_mo}Mo in #{ag.name}"] if not limit_ok
        return [false, "Blocked by #{ag.name}"] if match_time
      when /block/
        dputs(4){"block"}
        return [false, "Blocked by #{ag.name}"] if (match_time and match_user)
      when /allow/
        dputs(4){"allow"}
        return [true, "#{ag.name}"] if (match_time and match_user and limit_ok)
      end
    }
    dputs(4){"Nothing found - must be OK"}
    return [true, "default"]
  end
  
  def self.allow_user_now( user )
    self.allow_user( user, Time.now )
  end
end

class AccessGroup < Entity
  
  def self.time_in_atime( t, a )
    dow_raw, start_raw, stop_raw = a.split(";")
    {:di=>0,:lu=>1,:ma=>2,:me=>3,:je=>4,:ve=>5,:sa=>6}.each{|k,v|
      dow_raw.gsub!(/#{k}/,"#{v}")
    }
    dputs(4){"dow_raw is #{dow_raw}"}
    dow = []
    dow_raw.split(",").each{|d|
      if d =~ /(.)-(.)/
        b, e = $1.to_i, $2.to_i
        if e < b
          e += 7
        end
        (b..e).each{|i|
          dow.push(i % 7)
        }
      else
        dow.push d.to_i
      end
    }
    start_raw = start_raw.split(":")
    start = start_raw[0].to_i * 60 + start_raw[1].to_i
    stop_raw = stop_raw.split(":")
    stop = stop_raw[0].to_i * 60 + stop_raw[1].to_i
    if stop == 0
      stop = 24 * 60
    end
    time = t.hour * 60 + t.min
    time_dow = t.wday
    dputs(4){"dow:#{dow.inspect} - start:#{start} - stop:#{stop}"}
    dputs(4){"time: #{time} - time_dow:#{time_dow}"}
    
    # If we start in the evening and end in the morning...
    if start > stop and time < stop
      return ( dow.index( ( time_dow + 6 ) % 7 ) ) != nil
    end
    ( dow.index( time_dow ) and start <= time and time < stop ) == true
  end
  
  def time_in_atimes( t )
    if access_times
      ret = false
      access_times and access_times.each{|a|
        ret = ( ret or AccessGroup.time_in_atime( t, a ) )
      }
      return ret
    else
      return true
    end
  end
end
