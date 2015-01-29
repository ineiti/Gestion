class AdminServer < View
  def layout
    @functions_need = [:course_client]
    @order = 300

    gui_vbox do
      show_button :import_ctypes

      gui_window :win_import_ctypes do
        show_html :status
        show_list :ctypes_server
        show_button :download, :close
      end
    end
  end

  def rpc_button_import_ctypes(session, data)
    downloading = false
    status =
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
    reply(:window_show, :win_import_ctypes).concat(
        [status_list(true, status: status),
         (downloading ? reply(:callback_button, :download_list) : reply(:update))]).flatten
  end

  def rpc_button_download_list(session, data)
    (res = ICC.get(:AdminServer, :list)).inspect
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
    (cts = ICC.get(:AdminServer, :fetch,
                   args: {course_type_names: cts_names})).inspect
    if cts._code == 'Error'
      return status_list(true, status: "Error: #{cts._msg}")
    end

    log_msg :CourseType, "Downloaded #{cts_names}"
    cts._msg.each { |ct|
      log_msg :CourseType, "Creating CourseType #{ct._name}"
      CourseTypes.create(ct)
    }
    vtlp_update_list(session).concat(
        status_list(true, status: "Downloaded #{cts_names.length} CourseTypes"))
  end

  def status_list(show_status, status: '', list: [])
    reply_one_two(show_status, :close, :download) +
        reply_one_two(show_status, :status, :ctypes_server).concat(
            show_status ? reply(:update, status: status) :
                reply(:empty, :ctypes_server) +
                    reply(:update, ctypes_server: list)
        ).flatten
  end

end