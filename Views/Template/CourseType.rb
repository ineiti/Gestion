# To change this template, choose Tools | Templates
# and open the template in the editor.

class TemplateCourseType < View
  include VTListPane

  def layout
    set_data_class :CourseTypes
    @update = :before
    @order = 100

    @functions_need = [:courses]

    gui_hboxg do
      gui_vbox :nogroup do
        vtlp_list :ctype, 'name', :flexheight => 1
        show_button :new, :delete
      end

      gui_vboxg do
        gui_hboxg :nogroup do
          gui_vboxg :nogroup do
            show_block :strings
            show_block :long
            show_block :accounting
          end
          gui_vbox :nogroup do
            show_block :central
            show_field :page_format
            show_list_drop :file_diploma, 'CourseTypes.files.sort', :width => 200
            show_list_drop :file_exam, 'CourseTypes.files.sort', :width => 200
          end
        end
        gui_hboxg :nogroup do
          gui_vboxg :nogroup do
            show_int_ro :tests_nbr
            show_text :tests_str, :flexheight => 1, :width => 200
          end
          gui_vboxg :nogroup do
            show_int_ro :files_nbr
            show_text :files_str, :flexheight => 1, :width => 200
          end
        end
        gui_vbox :nogroup do
          show_field :account_base
          show_arg :account_base, :width => 400
        end
        show_button :save
      end
    end
  end

  def rpc_update_view(session)
    super(session) +
        reply(:empty_nonlists) +
        reply(:select, account_base: AccountRoot.actual.listp_path) +
        reply_visible(ConfigBase.has_function?(:accounting_courses),
                      :account_base)
  end

  def rpc_update(session)
    reply(:update, :account_base => [0])
  end
end
