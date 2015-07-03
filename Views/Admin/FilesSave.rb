class AdminFilesSave < View
  attr_accessor :files_dir

  def layout
    @order = 50
    @files_dir = '/opt/Files'
    gui_vboxg do
      show_list_single :dirs, 'View.AdminFilesSave.list_dirs',
                       callback: true, flexheight: 1

      gui_window :download_win do
        show_html :download_txt
        show_button :close
      end
    end
  end

  def list_dirs
    Dir.glob("#{@files_dir}/*/*").collect{|d| d.gsub(/^#{@files_dir}\//, '')}
  end

  def rpc_list_choice_dirs(session, data )
    return unless data._dirs.length > 0
    dir = data._dirs.first
    return unless File.exists?("#{@files_dir}/#{dir}")
    name = Date.today.strftime('%y%m%d') + "-#{dir.gsub(/\//, '_')}-files.tgz"
    System.run_str("tar czf /tmp/#{name} -C #{@files_dir} #{dir}")
    reply(:window_show, :download_win) +
        reply(:update, download_txt: "Click to download <a href='/tmp/#{name}'>#{name}</a>")
  end
end