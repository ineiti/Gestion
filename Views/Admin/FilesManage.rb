# AdminFilesManage offers an interface to add files to the files.profeda.org
# site. Files are stored in a two-level structure: first os, then
# categories. A possible structure is as follows:
# Windows/Antivirus
# Windows/Office
# Mac/Office
# Mac/Utils
# Each file in the directory is accompanied by a .file that holds information
# about it like description, URL, tags.

class AdminFilesManage < View
  attr_accessor :files_dir

  def layout
    @order = 50
    @update = true
    @functions_need = [:files_manage]
    @dirs_os_list = Entities.Statics.get(:AdminFMOS)
    if @dirs_os_list.data_str.class != Array
      @dirs_os_list = []
    end
    @dirs_os_choice = @dirs_os_list.first

    @files_dir = '/opt/Files'
    gui_hboxg do
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_list_single :dirs_os, callback: true, flexheight: 1
          show_button :dirs_os_add, :dirs_os_del
        end

        gui_vbox :nogroup do
          show_list_single :dirs_type, callback: true, flexheight: 1
          show_button :dirs_type_add, :dirs_type_del
        end
      end

      gui_vbox :nogroup do
        show_list_single :files, '[]', callback: true, flexheight: 1
        show_button :file_add, :file_del
      end

      gui_vbox :nogroup do
        show_str_ro :file_name
        show_str :file_url
        show_str :file_short
        show_str :file_desc
        show_str :file_tags
      end

      gui_window :win_chose do
        show_list :win_list
        show_button :win_add_os, :win_add_type
      end
    end
  end

  def list_dirs(base)
    dputs(0) { "#{base} - #{Dir.glob("#{base}/*")}" }
    Dir.glob("#{base}/*").collect { |d| d.gsub(/^#{base}\//, '') }.sort
  end

  def rpc_button_dirs_os_add(session, data)
    reply(:window_show, :win_chose) +
    reply_show_hide(:win_add_os, :win_add_type) +
        reply(:empty_update, win_list: list_dirs(@files_dir))
  end

  def rpc_button_dirs_type_add(session, data)
    if @dirs_os_choice != ""
      reply(:window_show, :win_chose) +
          reply_show_hide(:win_add_type, :win_add_os) +
          reply(:empty_update, win_list: list_dirs("#{@files_dir}/#{@dirs_os_choice}"))
    end
  end

  def rpc_button_win_add_os(session, data)
    @dirs_os_list = (@dirs_os_list + data._win_list).uniq
    reply(:window_hide) +
        rpc_update(nil)
  end

  def rpc_button_win_add_type(session, data)
    @dirs_os_list = (@dirs_os_list + data._win_list).uniq
    reply(:window_hide) +
        rpc_update(nil)
  end

  def rpc_update(session)
    dputs(0) { "#{@dirs_os_list}" }
    reply(:update, dirs_os: @dirs_os_list)
  end


  def rpc_list_choice_dirs(session, data)
    return unless data._dirs.length > 0
    dir = data._dirs.first
    return unless File.exists?("#{@files_dir}/#{dir}")
    name = Date.today.strftime('%y%m%d') + "-#{dir.gsub(/\//, '_')}-files.tgz"
    System.run_str("tar czf /tmp/#{name} -C #{@files_dir} #{dir}")
    reply(:window_show, :download_win) +
        reply(:update, download_txt: "Click to download <a href='/tmp/#{name}'>#{name}</a>")
  end
end