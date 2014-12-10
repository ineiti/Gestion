class AdminAccounts < View
  def layout
    @order = 450
    @update = true
    set_data_class(:ConfigBases)

    gui_vbox do
      gui_hboxg :nogroup do
        show_block :accounts
        show_arg :server_url, :width => 300
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