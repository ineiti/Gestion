# To change this template, choose Tools | Templates
# and open the template in the editor.

class ComptaAdmin < View
  def layout
		@order = 10
		
		gui_hbox do
			show_button :archive
		end
  end
	
	def rpc_button_archive( session, data )
		Accounts.archive
	end
end
