# Permits a reboot of both the Gestion and the Dreamplug itself

class AdminPower < View
  def layout
    @order = 300
		
    gui_vbox do
      gui_vbox do
        show_button :reboot_gestion
      end
      gui_vbox do
        show_button :reboot_dreamplug
      end
      gui_vbox do
        show_button :update_files
      end
      gui_window :reload do
        show_html :txt
        show_button :OK
      end
    end
  end
	
  def rpc_button( session, name, data )
    msg = ""
    case name
    when /reboot_gestion/ then
      Thread.new{
        `nohup #{GESTION_DIR}/Binaries/start_gestion`
      }
      msg = "<h1>Recharger le navigateur avec ctrl+r ou F5</h1>"
    when /reboot_dreamplug/ then
      Thread.new{
        `nohup #{GESTION_DIR}/Binaries/reboot`
      }
      msg = "<h1>Recharger le navigateur avec ctrl+r ou F5</h1><br>" +
        "<h2>Attention: il faudra attendre au moins 2 minutes!</h2>"
    when /update_files/ then
      Thread.new{
        `nohup /home/ftp/Files/update_files`
      }
      msg = "<h1>Les fichiers vont être mises à jour - patience</h1>"
    when /OK/ then
      return reply( :window_hide )
    end
    reply( :window_show, :reload ) +
      reply( :update, :txt => msg )
  end
end
