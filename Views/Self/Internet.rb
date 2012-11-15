class SelfInternet < View
  def layout
    set_data_class :Persons
    @order = 10
		@update = true
		@auto_update = 5
    @auto_update_send_values = false

    gui_vbox do
      show_int_ro :credit
			show_html :connection_status
      show_button :connect, :disconnect
    end
  end
	
	def has_money( session )
		session.owner.credit.to_i >= $lib_net.call( :user_cost_max ).to_i
	end
	
	def update_connection_status( session )
		if has_money( session )
			status = $lib_net.call( :isp_connection_status ).to_i
			status_str = %w( None PPP PAP IP VPN )
			status_color = %w( ff0000 ff2200 ff5500 ffff88 88ff88 )
			status_width = %w( 25 30 35 100 150 )
			connection_status = "<td width='#{status_width[status]}" + 
				"' bgcolor='" +
				status_color[status] + "'>" + 
				status_str[status] + "</td><td bgcolor='ffffff'></td>"

			reply( :update, :connection_status => 
					"Etat de la connexion:<br>" + 
					"<table width='150px'><tr>" + 
					connection_status +
					"</tr></table>" )
		else
			reply( :update, :connection_status => "Not enough money in account" )
		end
	end
	
	def update_button( session )
		if has_money( session )
			connected = $lib_net.call_args( :user_connected, session.owner.login_name )
			dputs( 3 ){ "User_connected #{session.owner.login_name}: #{connected.inspect}" }
			if connected == "yes"
				reply( :hide, :connect ) +
					reply( :unhide, :disconnect )
			else
				reply( :unhide, :connect ) +
					reply( :hide, :disconnect )
			end
		else
			reply( :hide, :connect ) +
				reply( :hide, :disconnect )
		end
	end

	def rpc_update( session )
		reply( :update, update( session ) ) +
			update_connection_status( session ) +
			update_button( session )
	end
	
	def rpc_show( session )
		super( session ) +
			rpc_update( session )
	end

	def rpc_button_connect( session, data )
		if session.web_req
			ip = session.web_req.peeraddr[3]
			$lib_net.call_args( :user_connect, "#{ip} #{session.owner.login_name}" )
			sleep 1
			rpc_update( session )
		end
	end

	def rpc_button_disconnect( session, data )
		if session.web_req
			ip = session.web_req.peeraddr[3]
			$lib_net.call_args( :user_disconnect, "#{ip} #{session.owner.login_name}" )
			sleep 1
			rpc_update( session )
		end
	end
end
