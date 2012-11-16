=begin
Internet - an interface for the internet-part of Markas-al-Nour.
=end

module Internet
	def self.take_money
		if $lib_net.call( :isp_connection_status ).to_i >= 4
			$lib_net.call( :users_connected ).split.each{|u|
				ddputs(3){"User is #{u}"}
				cost = $lib_net.call( :user_cost_now ).to_i

				user = Persons.find_by_login_name( u )
				if user
					if user.groups and user.groups.index( 'freesurf' )
						ddputs(3){"User #{u} is on freesurf"}
					elsif user.credit.to_i >= cost
						ddputs(3){"Taking #{cost} credits from #{u} who has #{user.credit}"}
						user.credit = user.credit.to_i - cost
					else
						ddputs(2){"Kicking user #{u}"}
						$lib_net.call_args( :user_disconnect, 
							"#{user.session.web_req.peeraddr[3]} #{user.login_name}")
					end
				else
					ddputs(1){"Couldn't find user #{u}"}
				end
			}
		end
	end
	
  def self.check_services
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
  end
end
