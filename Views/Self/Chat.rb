# To change this template, choose Tools | Templates
# and open the template in the editor.

class SelfChat < View
  def layout
		@@disc = Array.new(20, "")
    @order = 100
		@update = true
		@auto_update = 5
    @auto_update_send_values = false

		gui_vbox do
			show_text :discussion, :width => 400
			show_str :talk
			show_button :send
		end
  end
	
	def rpc_update( session )
		reply( :update, :discussion => @@disc[-20..-1].join("\n") ) +
			reply( :focus, :talk)
	end
	
	def rpc_button_send( session, data )
		@@disc.push( "#{session.owner.login_name}: #{data['talk']}" )
		reply( :empty, [:talk] ) +
			rpc_update( session )
	end
end
