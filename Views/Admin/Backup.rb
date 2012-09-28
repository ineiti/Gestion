# Presents a simple interface to allow for backup and restore

class AdminBackup < View
  def layout
    @order = 200
		
		gui_hbox do
			gui_vbox do
				show_list_single :backups, "View.AdminBackup.list_backups", :width => 400
				show_button :do_backup, :do_restore
			end
		
			gui_window :reload do
				show_html :txt
			end
		end
  end
	
	def rpc_button_do_backup( session, data )
		Entities.save_all
		`#{GESTION_DIR}/Binaries/backup`
		reply( :empty, [ :backups ] ) + 
			reply( :update, :backups => list_backups )
	end
	
	def rpc_button_do_restore( session, data )
		file = data["backups"][0]
		if File::exists? "/var/www/Backups/#{file}"
			dputs 0, "Going to call backup for #{file}"
			Thread.new{
				`nohup #{GESTION_DIR}/Binaries/restore #{file}`
			}
			reply( :window_show, :reload ) +
				reply( :update, :txt => "<h1>Recharger le navigateur avec ctrl+r ou F5</h1>" )
		end
	end
	
	def list_backups
		`ls /var/www/Backups`.split( "\n" ).sort{|a,b| b <=> a}
	end
end
