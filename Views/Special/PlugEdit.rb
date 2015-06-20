class SpecialPlug < View
  include VTListPane

  def layout
    @order = 150
    set_data_class :Plugs
    @update = true

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :plugs, :center_name
        show_button :delete, :new
      end
      gui_vbox :nogroup do
        show_block :default
        show_arg :internal_id, :width => 150
        show_button :save
      end
      gui_vbox :nogroup do
        show_text :stats, height: 300, width: 250
        show_int_ro :operator
        show_int_ro :credit_left
        show_int :recharge_credit
        show_str :cmd_str
        show_button :recharge, :charge, :cmd
      end
    end
  end

  def rpc_update(session)
    op, cl = if $MobileControl
                [$MobileControl.operator_name,
                $MobileControl.operator_missing? ? -1 : $MobileControl.operator.credit_left]
             else
               ['None', -1]
             end
    reply(:update, operator: op,
          credit_left: cl)
  end

  def plugs(data)
    Plugs.match_by_plug_id(data._plugs.first)
  end

  def rpc_button_recharge(session, data)
    dp data._plugs
  end

  def rpc_button_charge(session, data )
    plugs(data).send_cmd_sms(:charge)
  end

  def rpc_button_cmd(session, data)
    plugs(data).send_cmd_sms(data._cmd_str.split(/,\s*/))
  end
end