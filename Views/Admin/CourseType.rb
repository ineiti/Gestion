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

  def rpc_updates(session)
    reply(:update, :account_base => [0])
  end

  def rpc_button_from_server(session, data)
    auto_update = 0
    reply(:window_show, :win_from_server) +
        reply_show_hide(:status, :ctypes_server) +
        reply_show_hide(:close, :download) +
        reply(:update, :status =>
            if ConfigBase.server_url.to_s.length == 0
              'No server defined, aborting'
            else
              if Persons.center
                auto_update = 3
                CourseTypes.fetch_server
                'Fetching CourseTypes from server'
              else
                'There is no center defined, aborting'
              end
            end ) +
        reply( :auto_update, auto_update)
    end
  end
