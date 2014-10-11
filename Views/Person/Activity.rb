class PersonActivity < View
  include VTListPane

  def layout
    @update = true
    @order = 40

    @functions_need = [:cashbox]

    gui_hboxg do
      gui_vboxg :nogroup do
        vtlp_list :activity, :name, :flexheight => 1
        show_block_ro :show, :flexwidth => 1
      end
      gui_vboxg :nogroup do
        show_date :date_start
        show_date_ro :date_end
        show_entity_movements_lazy :payments, :flexheight => 1
        show_button :pay, :delete, :print_card
      end
    end
  end

  def rpc_button_pay(session, data)

  end

  def rpc_button_delete(session, data)

  end

  def rpc_list_choice_activity(session, data)

  end

  def rpc_list_choice_persons(session, data)
    reply( :empty_selections )
  end
end

