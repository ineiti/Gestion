class AdminFunction < View
  def layout
    @order = 700
    @update = true
    set_data_class(:ConfigBases)

    gui_vbox do
      gui_hboxg :nogroup do
        gui_vboxg :nogroup do
          show_field :functions, :flexheight => 1
        end
        gui_vbox :nogroup do
          show_field :welcome_text, :width => 400, :flexheight => 1
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

  def list_usage
    index = 0
    @@usages.collect { |c|
      index += 1
      [index, c.to_sym]
    }
  end
end