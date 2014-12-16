class AdminConfiguration < View
  def layout
    @order = 450
    @update = true
    set_data_class(:ConfigBases)

    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_block :vars_wide
          show_field :template_dir
          show_list_drop :card_student, 'ConfigBase.templates'
          show_list_drop :card_responsible, 'ConfigBase.templates'
          show_arg :server_url, :width => 300
        end
        gui_vbox :nogroup do
          show_block :narrow
          show_block :vars_narrow
        end
      end
      show_button :save
    end
  end

  def rpc_update(session)
    reply(:empty_fields) +
        update_form_data(ConfigBases.singleton)
  end

  def rpc_button_save(session, data)
    ConfigBase.store(data.to_sym)
    dputs(3) { "Configuration is now #{ConfigBase.get_functions.inspect}" }

    rpc_update(session)
  end
end