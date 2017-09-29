class AdminUpdate < View
  def layout
    @order = 550
    @update = true

    gui_hbox do
      gui_vbox :nogroup do
        show_list_single :update_files, width: 300
        show_upload :upload_update, callback: true
        show_button :update, :delete
      end

      gui_window :confirm_win do
        show_html :confirm_html
        show_button :confirm_ok, :close
      end
    end
  end

  def list_http
    []
  end

  def list_usb
    []
  end

  def list_tmp
    Dir.glob('/tmp/*.pkg.tar.*z').collect { |f| "file://#{f}" }
  end

  def list_files
    list_http + list_usb + list_tmp
  end

  def rpc_update(_session, select = [])
    reply(:empty_update, update_files: (list_files + select)) +
        reply(:update, upload_update: 'Upload')
  end

  def rpc_button_update(session, data)
    reply(:window_show, :confirm_win) +
        reply(:update, confirm_html: '<h1>Updating - Danger!</h1>' +
                         'Are you sure you want to update with<br>' +
                         "<strong>#{data._update_files.first}</strong>?") +
        reply(:select, update_files: [data._update_files.first])
  end

  def rpc_button_confirm_ok(session, data)
    file = data._update_files.first
    log_msg :AdminUpdate, "Preparing update with #{file}"
    Entities.save_all
    log_msg :backup, 'Creating new backup'
    System.run_bool "#{GESTION_DIR}/Binaries/backup"
    System.run_bool "#{GESTION_DIR}/Binaries/gestion_update.rb #{file}"
    Platform.start 'gestion_update'
    reply(:eval, "document.location.href='http://local.profeda.org/update_progress.html'")
  end

  def rpc_button_delete(session, data)
    return unless session.owner.permissions.index :admin
    case data._update_files
      when /^file:\/\/(.*)/
        File.exists? $1 and FileUtils.rm $1
    end
  end

  def rpc_button_upload_update(session, data)
    file = ["file:///tmp/#{data._filename}"]
    rpc_update(session, file) +
        rpc_button_update(session, update_files: file)
  end
end