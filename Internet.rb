=begin
Internet - an interface for the internet-part of Markas-al-Nour.
=end

module Internet
  def self.take_money
    if $lib_net.call( :isp_connection_status ).to_i >= 4
      $lib_net.call( :users_connected ).split.each{|u|
        dputs(3){"User is #{u}"}
        cost = $lib_net.call( :user_cost_now ).to_i

        user = Persons.find_by_login_name( u )
        if user
          if not self.free( user )
            if user.credit.to_i >= cost
              dputs(3){"Taking #{cost} credits from #{u} who has #{user.credit}"}
              user.credit = user.credit.to_i - cost
            else
              dputs(2){"Kicking user #{u}"}
              $lib_net.call_args( :user_disconnect_name, 
                "#{user.login_name}")
            end
          end
        else
          dputs(1){"Couldn't find user #{u}"}
        end
      }
    end
  end
	
  def self.check_services
    if false
      groups_all = Entities.Services.search_all.collect{|s| s[:group] }
      Entities.Persons.search_all.each{|p|
        dputs( 4 ){ "For #{p.login_name}" }
        groups_add = p.services_active.collect{|s| s[:group] }
        groups_del = groups_all.select{|g| groups_add.index(g) }
        if groups_add.size > 0
          dputs( 3 ){ "Adding groups #{groups_del.inspect}" }
        end
        if groups_del.size > 0
          dputs( 3 ){ "Deleting groups #{groups_del.inspect}" }
        end
      }
    else
      dputs(2){"Not updating Internet::check_services"}
    end
  end
  
  def self.free( user )
    if user
      # We want an exact match, so we put the name between ^ and $
      courses = Entities.Courses.search_by_students( "^#{user.login_name}$" )
      if courses
        dputs( 3 ){ "Courses : #{courses.inspect}" }
        courses.each{|c|
          dputs(3){"Searching course #{c}"}
          if c.name and c.start and c.end
            dputs(3){"Searching course"}
            dputs( 0 ){ [ c.name, c.start, c.end ].inspect }
            begin
              c_start = Date.strptime( c.start, "%d.%m.%Y" )
              c_end = Date.strptime( c.end, "%d.%m.%Y" )
            rescue
              c_start = c_end = Date.new
            end
            if c_start <= Date.today and Date.today <= c_end
              return true
            end
          end
        }
      end
      dputs(3){"Searching groups for user #{user.login_name}: #{user.groups.inspect}"}
      if user.groups and user.groups.index( 'freesurf' )
        dputs(3){"User #{user.login_name} is on freesurf"}
        return true
      end
      if Permission.can_view( user.permissions, "FlagInternetFree" )
        dputs(3){"User #{user.login_name} has FlagInternetFree" }
        return true
      end
    end
    dputs(3){"Found nothing"}
    return false
  end

  def self.connect_user( ip, name )
    $lib_net.call_args( :user_connect, "#{ip} #{name}" )
  end
end
