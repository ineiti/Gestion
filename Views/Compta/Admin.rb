# To change this template, choose Tools | Templates
# and open the template in the editor.

class ComptaAdmin < View
  def layout
		@order = 10
		
		gui_hbox do
			show_button :archive
			show_button :update_totals
		end
  end
	
	def rpc_button_archive( session, data )
		Accounts.archive
	end
	
	def rpc_button_update_totals( session, data )
		Accounts.search_all.each{|a|
			dputs( 2 ){"Updating #{a.get_path}"}
			a.update_total
		}
	end
end
