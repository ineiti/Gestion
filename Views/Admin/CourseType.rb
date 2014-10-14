# To change this template, choose Tools | Templates
# and open the template in the editor.

class AdminCourseType < View
  include VTListPane

  def layout
    set_data_class :CourseTypes
    @update = :before

    @functions_need = [:courses]

    gui_hboxg do
      gui_vboxg :nogroup do
        vtlp_list :ctype, 'name', :flexheight => 1
        show_button :new, :from_server, :delete
      end

      gui_vboxg do
        gui_hbox :nogroup do
          gui_vboxg :nogroup do
            show_block :strings
            show_block :accounting
          end
          gui_vboxg :nogroup do
            show_block :central
          end
        end
        gui_vbox :nogroup do
          show_field :account_base
          show_arg :account_base, :width => 400
        end
        gui_vboxg :nogroup do
          show_block :long, :width => 200
          show_field :page_format
          show_list_drop :filename, 'CourseTypes.files.sort'
        end
        show_button :save
      end

      gui_window :win_from_server do
        show_html :status
        show_list :ctypes_server
        show_button :download, :close
      end
    end
  end

  def rpc_update_view(session)
    reply(:empty_fields, :account_base) +
        reply(:update, :account_base => AccountRoot.actual.listp_path) +
        reply_visible(ConfigBase.has_function?(:accounting_courses),
                      :account_base)
  end

  def rpc_update(session)
    reply(:update, :account_base => [0])
  end

  def status_list(show_status, status: '', list: [])
    reply_one_two(show_status, :close, :download) +
        reply_one_two(show_status, :status, :ctypes_server).concat(
            show_status ? reply(:update, status: status) :
                reply(:empty, :ctypes_server) +
                    reply(:update, ctypes_server: list)
        ).flatten
  end

  def rpc_button_from_server(session, data)
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
    reply(:window_show, :win_from_server).concat(
        [status_list(true, status: status),
         (downloading ? reply(:callback_button, :download_list) : reply)]).flatten
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
      log_msg :CourseType, "Creating CourseType #{ct._name}"
      CourseTypes.create(ct)
    }
    vtlp_update_list(session).concat(
        status_list(true, status: "Downloaded #{cts_names.length} CourseTypes"))
  end
end
