# Used for returning some information about the internal state
# SHOULD NOT CHANGE ANYTHING IN HERE, JUST READING, INFORMATION!


class ACaccess
  def self.date(args)
    dputs 3, "Arguments are: #{args.inspect}"
    return Time.new.to_s
  end
	
	def self.print_movements( accounts, start, stop )
		start, stop = start.to_i, stop.to_i
		dputs 2, "Doing print_movements from #{start.class} to #{stop.class}"
		ret = ""
		Movement.find(:all, :conditions => 
				{:index => start..stop } ).each{ |m|
			if start > 0
				dputs 4, "Mer: Movement #{m.desc}, #{m.value}"
			end
			ret += m.to_s + "\n"
		}
		return ret
	end
    
	def self.get(p)
		# Two cases:
		# path/arg/user,pass - arg is used
		# path/user,pass - arg is nil
		path, arg, id = p.split("/")
		arg, id = id, arg if not id
		user, pass = id.split(",")
      
		dputs 1, "get-merge-path #{path} - #{arg} with user #{user} and pass #{pass}"
		u = User.find_by_name( user )
		u_local = User.find_by_name('local')
		if not ( u and u.pass == pass )
			return "User " + user + " not known with pass " +
        pass
		end
		case path
        
			# Gets all accounts available (to that user) that have been changed
			# since the last update, again, do it from the root(s), else we have
			# a problem for children without parents
		when /accounts_get(.*)/
			ret = ""
			dputs 2, "user index is: #{u.account_index}"
			# Returns only one account
			if $1 == "_one"
				return Account.find_by_global_id( arg )
			end
			get_all = $1 == "_all"
			Account.find_all_by_account_id(0).to_a.each{|a|
				if a.global_id
					a.get_tree{|acc|
						if acc.index > u.account_index or get_all
							dputs 2, "Found account #{acc.name} with index #{acc.index}"
							ret += "#{acc.to_s( get_all )}\n"
						end
					}
				end
			}
			u.update_account_index
			return ret
        
			# Gets all movements (for the accounts of that user)
		when /movements_get(.*)/
			dputs 2, "movements_get#{$1}"
			start, stop = u.movement_index + 1, u_local.movement_index - 1
			# Returns only one account
			if $1 == "_one"
				return Movement.find_by_global_id( arg )
			end
			if $1 == "_all"
				start, stop = arg.split(/,/)
			end
			ret = print_movements( Account.find(:all), start, stop )
			u.update_movement_index
			dputs 3, "Sending:\n #{ret}"
			return ret
        
		when "version"
			return @VERSION.to_s
        
		when "index"
			return [ u_local.account_index, u_local.movement_index ].join(",")
        
		when "users_get"
			return User.find(:all).join("/")
		end
	end
    
	def self.post(path)
		dputs 1, "post-merge-path #{path} with user #{input.user} and pass #{input.pass}"
		u = User.find_by_name( input.user )
		if not (  u and u.pass == input.pass )
			dputs 0, "Didn't find user #{user}"
			return "User " + user + " not known with pass " +
        pass
		end
		case path
			# Retrieves id of the path of the account
		when /account_get_id/
			dputs 2, "account_get_id with path #{input.account}"
			Account.find(:all).to_a.each{|a|
				if a.global_id and a.path =~ /#{input.account}/
					dputs 2, "Found #{a.inspect}, a.id is #{a.id}"
					return a.id.to_s
				end
			}
			dputs 2, "didn't find anything"
			return nil

		when "movements_put"
			dputs 3, "Going to put some movements"
			movs = ActiveSupport::JSON.decode( input.movements )
			if movs.size > 0
				movs.each{ |m|
					mov = Movement.from_json( m )
					dputs 2, "Saved movement #{mov.global_id}"
					u.update_movement_index
				}
			end
		when "movement_delete"
			dputs 3, "Going to delete movement"
			Movement.find_by_global_id( input.global_id ).delete
		when "account_put"
			dputs 3, "Going to put account"
			acc = Account.from_s( input.account )
			u.update_account_index
			dputs 2, "Saved account #{acc.global_id}"
		when "account_delete"
			dputs 3, "Going to delete account"
			Account.find_by_global_id( input.global_id ).delete
		end
	end
end

class RPCQooxdooHandler
def self.parse_acaccess( p, q )
	dputs 0, "in ACaccess: #{p} - #{q.inspect}"
	method = p.gsub( /^.info./, '' )
	dputs 3, "Calling method #{method}"
	ACaccess.send( method, q.to_sym )
end
end
