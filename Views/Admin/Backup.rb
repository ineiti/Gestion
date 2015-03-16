# Presents a simple interface to allow for backup and restore

class AdminBackup < View
  def layout
    @order = 200
    @update = true

    gui_hbox :nogroup do
      gui_vbox do
        show_list_single :backups, 'View.AdminBackup.list_backups', :width => 400
        show_upload :upload_backup
        show_button :do_backup, :do_restore
        #show_button :do_send, :do_fetch
      end

      gui_window :reload do
        show_html :txt
        show_button :close
      end

      gui_window :remote do
        show_str :host
        show_str :user
        show_str :pass
        show_button :connect
      end
    end
  end

  def rpc_update(session)
    reply(:update, upload_backup: 'Upload backup')
  end

  def rpc_button_upload_backup(session, data)
    file = data._filename
    if file =~ /.tar.gz$/
      FileUtils.mv file, "#{GESTION_DIR}/Backups"
    else
      reply(:window_show, :reload) +
          reply(:update, txt: "#{file} does not end in .tar.gz")
    end
  end

  def rpc_button_do_backup(session, data)
    Entities.save_all
    log_msg :backup, 'Creating new backup'
    System.run_bool "#{GESTION_DIR}/Binaries/backup"
    reply(:empty_update, backups: list_backups)
  end

  def rpc_button_do_restore(session, data)
    file = data['backups'][0]
    if File::exists? "Backups/#{file}"
      dputs(1) { "Going to call restore for #{file}" }
      File.open('dorestore', 'w') { |f| f.write file }
      Thread.new {
        System.run_bool 'systemctl restart gestion'
      }
      reply(:window_show, :reload) +
          reply(:update, :txt => '<h1>Recharger le navigateur avec ctrl+r ou F5</h1>')
    end
  end

  def rpc_button_do_send(session, data)
    center = session.owner
    if not center.permissions.index(:center)
      reply(:window_show, :remote)
    else
      rpc_button_connect(session, data.merge)
    end
  end

  def rpc_button_do_fetch(session, data)

  end

  def list_backups
    System.run_str('ls Backups').split("\n").sort { |a, b| b <=> a }
  end
end
