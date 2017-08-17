# To change this template, choose Tools | Templates
# and open the template in the editor.

class TemplateActivity < View
  include VTListPane

  def layout
    #set_data_class :Activities
    @order = 200

    @functions_need = [:activities]

    gui_hboxg do
      gui_vboxg :nogroup do
        vtlp_list :activity, 'name', :flexheight => 1
        show_button :new, :delete
      end

      gui_vboxg :nogroup do
        show_block :default
        show_block :show
        show_list_drop :card_filename, 'Activities.files.sort'
        show_field :tags
        show_field :internet_limit
        show_button :save
      end
    end
  end

  def rpc_list_choice_internetClass(session, name, args)
    # dp name, args
  end
end
