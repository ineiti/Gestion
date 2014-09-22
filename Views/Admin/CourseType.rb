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
    reply(:empty, :account_base) +
        reply(:update, :account_base => AccountRoot.actual.listp_path) +
        reply_visible(ConfigBase.has_function?(:accounting_courses),
                      :account_base)
  end

  def rpc_update(session)
    reply(:update, :account_base => [0])
  end

  def rpc_button_from_server(session, data)
    downloading = false
    reply(:window_show, :win_from_server) +
        reply_show_hide(:status, :ctypes_server) +
        reply_show_hide(:close, :download) +
        reply(:update, :status =>
            if ConfigBase.server_url.to_s.length == 0
              'No server defined, aborting'
            else
              if Persons.center
                downloading = true
                'Fetching CourseTypes from server'
              else
                'There is no center defined, aborting'
              end
            end) +
        (downloading ? reply(:callback_button, :download_list) : reply)
  end

  def rpc_button_download_list(session, data)
    #dp (res = ICC.transfer('CourseTypes.list')).inspect
    dp ( res = ICC.get( :CourseTypes, :list ) ).inspect
    if res !=~/^Error: /
      dp ct_list = JSON.parse(res)
      reply_show_hide(:ctypes_server, :status) +
          reply(:update, :ctypes_server => ct_list) +
          reply(:unhide, :download)
    else
    end
  end
end
