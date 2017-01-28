class AdminUpdateSystem < View
  def layout
    @order = 60
    @functions_need = [:files_manage]
    @visible = false

    gui_vbox do
      show_upload :update, :callback => true
    end
  end

  def rpc_button_update(session, data)
    file = UploadFiles.escape_chars(data._filename)
    return unless File.exists?("/tmp/#{file}")
    dir = /^[^-]*-(.*)-files.*/.match(file)[1].gsub(/_/, '/')
    if dir =~ /\./
      dputs(0){"Error: tried to upload file to #{dir}"}
      return reply(:window_hide)
    end
    files_dir = View.AdminFilesSave.files_dir
    FileUtils.rm_rf("#{files_dir}/#{dir}")
    System.run_str("tar xf /tmp/#{file} -C #{files_dir}")
    log_msg :Files, "Installed #{file}"
    reply(:window_hide)
  end
end