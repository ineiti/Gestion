class InternetClassEdit < View
  include VTListPane

  def layout
    set_data_class :InternetClasses
    @order = 400

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :classes, :name
        show_button :new, :delete
      end
      gui_vbox :nogroup do
        show_block :default
        show_arg :type, callback: true
        show_button :save
      end
    end
  end

  def rpc_list_choice_type(session, data)
    reply_visible(data._type.first == 'limit_daily', :limit_mo)
  end
end