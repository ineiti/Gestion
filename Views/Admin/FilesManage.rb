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
        show_list_single :files_stored, '[]', callback: true, flexheight: 1
        show_button :file_save, :file_del, :file_new
      end

      gui_vbox :nogroup do
        show_str_ro :file_name, width: 300
        show_str :file_url
        show_str :file_short
        show_str :file_desc
        show_str :file_tags
      end

      gui_window :win_chose do
        show_list :win_list
        show_button :win_add_os, :win_add_type, :win_add_file
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
    dputs(0) { "Dirs_os: #{data}" }
    return unless data._dirs_os.length > 0
    dir = data._dirs_os.first
    reply(:window_show, :win_chose) +
        reply_show_hide(:win_add_type, :win_add_os) +
        reply(:empty_update, win_list: list_dirs(File.join(@files_dir, dir)))
  end

  def rpc_button_win_add_os(session, data)
    data._win_list.each { |name|
      FMDirs.create({name: name})
    }
    reply(:window_hide) +
        rpc_update(nil)
  end

  def rpc_button_win_add_type(session, data)
    data._win_list.each { |name|
      FMDirs.create({name: name, parent: data._dirs_os.first})
    }
    reply(:window_hide) +
        rpc_list_choice_dirs_os(session, data)
  end

  def rpc_update(session)
    dputs(0) { "#{FMDirs.base_dirs}" }
    reply(:update, dirs_os: FMDirs.base_dirs.map { |f| f._name })
  end


  def rpc_list_choice_dirs_os(session, data)
    dputs(0) { "#{data.inspect}, #{data._dirs_os.length}" }
    return [] unless data._dirs_os.length > 0
    dir = data._dirs_os.first
    dirs = FMDirs.sub_dirs(dir).map { |f| f._name }
    dputs(0){dirs.inspect}
    reply(:empty_update, dirs_type: dirs)
  end

  def rpc_list_choice_dirs_type(session, data)
    dputs(0){data.inspect}
    return [] unless data._dirs_type.length > 0
    dir = FMDirs.search_by_path(data._dirs_type.first, data._dirs_os.first)
    dputs(0){dir.inspect}
    entries = FMEntries.search_by_directory(dir)
    files = Dir.glob(dir.path)
    return entries
  end
end