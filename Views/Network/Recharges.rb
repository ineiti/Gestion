class NetworkRecharges < View
  def layout
    @order = 150
    @update = true
    @functions_need = [:sms_control, :network_pro]
    set_data_class :Recharges

    gui_hbox do
      gui_vbox do
        show_entity_recharge_all :recharges, :single, :time,
                                 flexheight: 1, width: 200, callback: true
        show_button :new, :delete
      end
      gui_vbox do
        show_block :default, width: 200
        show_button :save
      end
    end
  end

  def rpc_update(_session, select = nil)
    recharges = Recharges.search_all_.collect { |r| [r.recharge_id, r.time] }
    select and recharges.push(select)
    reply(:empty_nonlists) +
        reply(:empty, :recharges) +
        reply(:update, recharges: recharges)
  end

  def rpc_button_new(session, data)
    reply(:empty_nonlists)
  end

  def rpc_button_save(session, data)
    data._recharges.data_set_hash(data)
    rpc_update(session, data._recharges.recharge_id)
  end

  def rpc_button_delete(session, data)
    return unless data._recharges.class == Entities::Recharge
    data._recharges.delete
    rpc_update(session)
  end

  def rpc_list_choice_recharges(session, data)
    reply(:empty_nonlists) +
        reply(:update, data._recharges.to_hash)
  end
end