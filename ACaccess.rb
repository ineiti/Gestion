# Used for returning some information about the internal state
# SHOULD NOT CHANGE ANYTHING IN HERE, JUST READING, INFORMATION!

$VERSION = 0x1000

class ACaccess
	def self.print_movements( accounts, start, stop )
		start, stop = start.to_i, stop.to_i
		dputs 2, "Doing print_movements from #{start.class} to #{stop.class}"
		ret = ""
		Movements.search_all.select{|m|
			m.index >= start and m.index <= stop }.each{ |m|
			if start > 0
				dputs 4, "Mer: Movement #{m.desc}, #{m.value}"
			end
			ret += m.to_s + "\n"
		}
		ret
	end
    
	def self.get( p )
		# Two cases:
		# path/arg/user,pass - arg is used
		# path/user,pass - arg is nil
		path, arg, id = p.split("/")
		arg, id = id, arg if not id
		user, pass = id.split(",")
      
		dputs 1, "get-merge-path #{path} - #{arg} with user #{user} and pass #{pass}"
		u = Users.find_by_name( user )
		u_local = Users.find_by_name('local')
		if not ( u and u.pass == pass )
			return "User " + user + " not known with pass " +
        pass
		end

		case path        
		when /accounts_get(.*)/
			# Gets all accounts available (to that user) that have been changed
			# since the last update, again, do it from the root(s), else we have
			# a problem for children without parents
			ret = ""
			dputs 2, "user index is: #{u.account_index}"
			# Returns only one account
			if $1 == "_one"
				return Accounts.find_by_global_id( arg ).to_s
			end
			get_all = $1 == "_all"
			Accounts.search_by_account_id(0).to_a.each{|a|
				if a.global_id
					a.get_tree{|acc|
						if acc.index > u.account_index or get_all
							dputs 4, "Found account #{acc.name} with index #{acc.index}"
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
				return Movements.find_by_global_id( arg ).to_s
			end
			if $1 == "_all"
				start, stop = arg.split(/,/)
			end
			ret = print_movements( Accounts.search_all, start, stop )
			u.update_movement_index
			dputs 3, "Sending:\n #{ret}"
			return ret
        
		when "version"
			return $VERSION.to_s
        
		when "index"
			return [ u_local.account_index, u_local.movement_index ].join(",")
        
		end
	end
    
	def self.post( path, input )
		ddputs 5, "self.post with #{path} and #{input.inspect}"
		dputs 1, "post-merge-path #{path} with user #{input['user']} " + 
			"and pass #{input['pass']}"
		user, pass = input['user'], input['pass']
		u = Users.find_by_name( user )
		if not ( u and u.pass == pass )
			dputs 0, "Didn't find user #{user}"
			return "User " + user + " not known with pass " +
				pass
		end
		case path
			# Retrieves id of the path of the account
		when /account_get_id/
			account = input['account']
			dputs 2, "account_get_id with path #{account}"
			Accounts.search_all.to_a.each{|a|
				if a.global_id and a.path =~ /#{account}/
					dputs 2, "Found #{a.inspect}, a.id is #{a.id}"
					return a.id.to_s
				end
			}
			dputs 2, "didn't find anything"
			return nil

		when "movements_put"
			dputs 3, "Going to put some movements"
			movs = ActiveSupport::JSON.decode( input['movements'] )
			dputs 3, "movs is now #{movs.inspect}"
			if movs.size > 0
				movs.each{ |m|
					mov = Movements.from_json( m )
					dputs 2, "Saved movement #{mov.global_id}"
					u.update_movement_index
				}
			end
		when "movement_delete"
			dputs 3, "Going to delete movement"
			Movements.find_by_global_id( input['global_id'] ).delete
		when "account_put"
			dputs 3, "Going to put account"
			acc = Accounts.from_s( input['account'] )
			u.update_account_index
			dputs 2, "Saved account #{acc.global_id}"
		when "account_delete"
			dputs 3, "Going to delete account"
			Accounts.find_by_global_id( input['global_id'] ).delete
		end
		return "ok"
	end
end

class RPCQooxdooHandler
	def self.parse_acaccess( r, p, q )
		dputs 0, "in ACaccess: #{p} - #{q.inspect}"
		method = p.gsub( /^.acaccess./, '' )
		dputs 3, "Calling method #{method} of #{r}"
		case r
		when /GET/
			ACaccess.get( method )
		when /POST/
			ACaccess.post( method, q )
		end
	end
end
