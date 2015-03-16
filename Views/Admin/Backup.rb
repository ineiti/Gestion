# Presents a simple interface to allow for backup and restore
#
# The following functions are implemented:
# do_backup - call Binaries/backup to save files in data, Exas and Diplomas
# do_restore - re-starts Gestion which will restore the backupped data
# upload_backup - send a backup-file to the server
# download_backup - get a backup-file from the server

class AdminBackup < View
  def layout
    @order = 200
    @update = true

    gui_hbox :nogroup do
      gui_vbox do
        show_list_single :backups, 'View.AdminBackup.list_backups', :width => 400
        show_upload :upload_backup, callback: true
        show_button :do_backup, :do_restore, :do_download
      end

      gui_window :status do
        show_html :txt
        show_button :restore, :close
      end
    end
  end

  def rpc_update(session)
    reply(:update, upload_backup: 'Upload backup')
  end

  def rpc_button_upload_backup(session, data)
    file = data._filename
    if file =~ /\.tgz$/
      FileUtils.mv "/tmp/#{file}", "#{GESTION_DIR}/Backups"
      reply(:empty_update, backups: list_backups) +
          reply(:select, backups: [file]) +
          reply(:window_show, :status) +
          reply(:unhide, %w(close restore)) +
          reply(:update, txt: "Do you want to restore #{file}?")
    else
      reply(:window_show, :status) +
          reply_show_hide(:close, :restore) +
          reply(:update, txt: "#{file} does not end in .tgz")
    end
  end

  def rpc_button_restore(session, data)
    rpc_button_do_restore(session, data)
  end

  def rpc_button_do_download(session, data)
    if file = data._backups[0]
      FileUtils.cp "#{GESTION_DIR}/Backups/#{file}", "/tmp/#{file}"
      reply(:eval, "window.open('/tmp/#{file}', '_blank');") +
          reply(:window_show, :status) +
          reply_show_hide(:close, :restore) +
          reply(:update, txt: 'If the file is not downloaded, click the following link:' +
                           "<br><a href='/tmp/#{file}' target='_blank'>#{file}</a>")
    else
      reply(:window_show, :status) +
          reply_show_hide(:close, :restore) +
          reply(:update, txt: 'Please chose a backup first')
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
      reply(:window_show, :status) +
          reply(:hide, %w(restore close)) +
          reply(:update, :txt => '<h1>Recharger le navigateur avec ctrl+r ou F5</h1>')
    end
  end

  def list_backups
    System.run_str('ls Backups').split("\n").sort { |a, b| b <=> a }
  end
end
