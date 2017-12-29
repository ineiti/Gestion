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
    gui_vbox do
      gui_hboxg :nogroup do
        gui_vbox :nogroup do
          gui_vbox :nogroup do
            show_list_single :dirs_os, callback: true, flexheight: 1
            show_button :dirs_os_add, :dirs_os_del
          end

          gui_vbox :nogroup do
            show_list_single :dirs_type, callback: true, flexheight: 1
          end
        end

        gui_vbox :nogroup do
          show_list_single :files_stored, '[]', callback: true, flexheight: 1
          show_button :file_del
        end

        gui_vbox :nogroup do
          show_str_ro :name, width: 300
          show_str_ro :url_file
          show_str :url_page
          show_str :description
          show_str :tags
          show_button :file_save, :file_rename
        end

        gui_window :win_chose do
          show_list :win_list
          show_button :win_add_os
        end

        gui_window :win_rename do
          show_str :new_name, width: 300
          show_button :rename_ok, :cancel
        end

        gui_window :win_update do
          show_html :update_txt
          show_button :update_ok
        end
      end
      gui_vbox :nogroup do
        show_button :files_search, :files_update
      end
    end
  end

  def list_dirs(base)
    Dir.glob("#{base}/*").collect { |d| d.gsub(/^#{base}\//, '') }.sort
  end

  def rpc_button_dirs_os_del(session, data)
    dir = FMDirs.search_by_path(data._dirs_os.first)
    return unless dir
    dir.delete
    rpc_update(session)
  end

  def rpc_button_dirs_os_add(session, data)
    dirs = list_dirs(@files_dir)
    FMDirs.base_dirs.each { |d|
      dirs.delete(d._name)
    }
    reply(:window_show, :win_chose) +
        reply(:empty_update, win_list: dirs)
  end

  def rpc_button_win_add_os(session, data)
    data._win_list.each { |name|
      if FMDirs.search_by_path(name, '') == nil
        FMDirs.create({name: name})
      else
        dputs(1) { "Os-dir #{name} already exists" }
      end
    }
    reply(:window_hide) +
        rpc_update(nil)
  end

  def rpc_button_files_update(session, data)
    Thread.start {
      System.run_bool "#{FMDirs.dir_base}/update_files do_dokuwiki"
    }
    rpc_update(session) +
        reply(:window_show, :win_update) +
        reply(:update, update_txt: 'Update might take quite some time<br>'+
                         'Check on <a href="http://files.profeda.org" target="other">files.profeda.org</a>')
  end

  def rpc_button_files_search(session, data)
    FMDirs.base_dirs.each { |d|
      d.update_dirs
    }
  end

  def rpc_button_update_ok(session, data)
    reply(:window_hide)
  end

  def rpc_button_file_save(session, data)
    file = get_file(data)
    return unless file
    data._tags = (data._tags || '').split(/,/).map { |t| t.sub(/^ */, '') }
    in_file { |f| file.data_set(f, data[f]) }
    file.save_file(true)
    rpc_list_choice_files_stored(session, data)
  end

  def rpc_button_file_del(session, data)
    file = get_file(data)
    return unless file
    file.delete
    rpc_list_choice_dirs_type(session, data)
  end

  def rpc_button_file_rename(session, data)
    file = get_file(data)
    return unless file
    reply(:update, new_name: file.file_name) +
        reply(:window_show, :win_rename)
  end

  def rpc_button_rename_ok(session, data)
    file = get_file(data)
    return unless file
    file.rename(data._new_name)
    reply(:window_hide) +
        rpc_list_choice_dirs_type(session, data)
  end

  def rpc_button_cancel(session, data)
    reply(:window_hide)
  end

  def rpc_update(session)
    empty_fields(3) +
        reply(:update, dirs_os: FMDirs.base_dirs.map { |f| f._name }.sort)
  end


  def rpc_list_choice_dirs_os(session, data)
    return [] unless data._dirs_os.length > 0
    dir = data._dirs_os.first
    dirs = FMDirs.sub_dirs(dir).map { |f| f._name }.sort
    empty_fields(2) +
        reply(:update, dirs_type: dirs)
  end

  def rpc_list_choice_dirs_type(session, data)
    return [] unless data._dirs_type.length > 0
    dir = FMDirs.search_by_path(data._dirs_type.first, data._dirs_os.first)
    entries = FMEntries.search_by_directory(dir)
    empty_fields(1) +
        reply(:update, files_stored: entries.map { |e| e._name }.sort)
  end

  def rpc_list_choice_files_stored(session, data)
    file = get_file(data)
    fields = {}
    in_file { |f| fields[f] = file.data_get(f) }
    fields._tags = fields._tags.join(', ')
    empty_fields(0) +
        reply(:update, fields)
  end

  def empty_fields(lvl)
    rep = %w(name url_file url_page description tags)
    if lvl > 0
      rep.push :files_stored
    end
    if lvl > 1
      rep.push :dirs_type
    end
    if lvl > 2
      rep.push :dirs_os
    end
    reply(:empty, rep)
  end

  def get_file(data)
    unless data._dirs_type.length > 0 && data._dirs_os.length > 0 &&
        data._files_stored.length > 0
      return nil
    end
    dir = FMDirs.search_by_path(data._dirs_type.first, data._dirs_os.first)
    FMEntries.search_by_name(data._files_stored.first).find { |e|
      e._directory == dir
    }
  end

  def in_file
    %w(name url_file url_page description tags).each { |f|
      yield f
    }
  end
end