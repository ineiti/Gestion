class NetworkConnection < View
  def layout
    set_data_class :ConfigBases
    #@visible = false
    @order = 100
    @update = true
    @functions_need = [:network]

    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_block :operator
          show_block :internet
        end
        gui_vbox :nogroup do
          show_block :captive
          show_arg :prerouting, :width => 300
        end
      end
      show_button :save_costs
    end
  end

  def rpc_button_save_costs(session, data)
    ConfigBase.data_set_hash(data)
    ConfigBase.send_config
  end

  def update(session)
    ConfigBase.to_hash
  end

  def rpc_update(session)
    super
  end
end
