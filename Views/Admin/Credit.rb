# Presents a simple interface to allow for backup and restore

class AdminCredit < View
  def layout
    @order = 300
    @visible = false
		
    gui_vbox do
      show_text :user_credit
      show_button :update_credits
    end
  end
	
  def rpc_button_update_credits( session, data )
    data['user_credit'].split(/\n/).each{|l|
      u, c = l.split
      if user = Persons.match_by_login_name(u)
        dputs(1){"Setting credit of #{u}:#{user.full_name} to #{c}"}
        user.credit = c.to_i
        if not user.permissions 
          user.permissions = ["internet"]
        elsif not user.permissions.index( "internet" )
          user.permissions.push "internet"
        end
      else
        dputs(1){"Didn't find #{u}"}
      end
    }
    Entities.save_all
    reply( :empty )
  end
end
