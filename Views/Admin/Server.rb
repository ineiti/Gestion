class AdminServer < View
  def layout
    @functions_need = [:course_client]
    @order = 300

    gui_vbox do
      show_button :import_ctypes
      show_button :import_courses

      gui_window :win_import do
        show_html :status
        show_list :import_list
        show_button :download, :close
      end
    end
  end

  def check_availability
    if ConfigBase.server_url.to_s.length == 0
      'No server defined, aborting'
    else
      if Persons.center
        downloading = true
        'Fetching CourseTypes from server'
      else
        'There is no center defined, aborting'
      end
    end
  end

  def status_list(show_status, status: '', list: [])
    reply_one_two(show_status, :close, :download) +
        reply_one_two(show_status, :status, :import_list) +
        reply(:update, import_list: list) +
        (show_status ? reply(:update, status: status) :
            reply(:empty, :import_list))
  end

  def rpc_button_import_ctypes(session, data)
    downloading, status = check_availability
    reply(:window_show, :win_import) +
        status_list(true, status: status) +
        (downloading ? reply(:callback_button, :download_list) : reply(:update))
  end

  def rpc_button_download_list(session, data)
    (res = ICC.get(:CourseTypes, :list)).inspect
    if res._code == 'Error'
      status_list(true, status: "Error: #{res._msg}")
    else
      status_list(false, list: res._msg)
    end
  end

  def rpc_button_download(session, data)
    if (cts_names = data._ctypes_server).length > 0
      status_list(true, status: "Downloading #{cts_names.length} CourseTypes").concat(
          reply(:callback_button, :fetch_list))
    else
      log_msg :CourseType, 'Nothing to download'
      reply(:window_hide)
    end
  end

  def rpc_button_fetch_list(session, data)
    cts_names = data._ctypes_server
    (cts = ICC.get(:CourseTypes, :fetch,
                   args: {course_type_names: cts_names})).inspect
    if cts._code == 'Error'
      return status_list(true, status: "Error: #{cts._msg}")
    end

    log_msg :CourseType, "Downloaded #{cts_names}"
    cts._msg.each { |ct|
      if ct_exist = CourseTypes.match_by_name(ct._name)
        log_msg :CourseType, "Updating CourseType #{ct._name}"
        ct_exist.data_set_hash(ct)
      else
        log_msg :CourseType, "Creating CourseType #{ct._name}"
        ct_new = CourseTypes.create(ct)
      end
      #/opt/profeda/Gestion/Views/Admin/Server.rb:71:in `block in rpc_button_fetch_list'
      [ct._file_diplomas, ct._file_exam].compact.each { |f|
        file = f.first
        if file.length > 0
          rep = ICC.get(:CourseTypes, :_file, args: {name: [file]})
          if rep._code == 'OK'
            file = rep._msg
            log_msg :CourseType, "Got file #{file} with length #{file.length}"
            IO.write("#{ConfigBase.template_dir}/#{file}", file)
          else
            log_msg :CourseType, "Got error #{rep._msg}"
          end
        end
      }
    }
    status_list(true, status: "Downloaded #{cts_names.length} CourseTypes")
  end

  def rpc_button_import_courses(session, data)
    case session.s_data._import_courses ||= 0
      when 0
        downloading, status = check_availability
        session.s_data._import_courses = downloading ? 1 : 10
        reply(:window_show, :win_import) +
            status_list(true, status: status) +
            (downloading ? reply(:callback_button, :download_list) : reply(:update))
      when 1
        (res = ICC.get(:Courses, :courses, args: {center: Persons.center})).inspect
        if res._code == 'Error'
          status_list(true, status: "Error: #{res._msg}")
        else
          status_list(false, list: res._msg)
        end
      when 2
      when 10
        reply(:window_hide)
    end
  end

end