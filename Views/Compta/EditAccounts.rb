class ComptaEditAccounts < View
  def layout
    @rpc_update = true
    @order = 100
    @functions_need = [:accounting]

    gui_hboxg do
      gui_vboxg :nogroup do
        show_entity_account_lazy :account_archive, :drop, :callback => true
        show_entity_account_lazy :account_list, :single,
                                 :width => 400, :flex => 1, :callback => true
      end
      gui_vbox :nogroup do
        show_str :name
        show_str :desc, :width => 300
        show_int :total
        show_button :save, :account_update
      end
    end
  end

  def rpc_button_account_update(session, data)
    if (acc = data._account_list).class == Account
      acc.update_total
    end
  end

  def rpc_button_save( session, data )
    if (acc = data._account_list).class == Account
      acc.desc, acc.name = data._desc, data._name
    end
  end

  def update_list(account = [])
    account.class == Account or account = AccountRoot.current

    reply(:empty_fields, :account_list) +
        reply(:update, :account_list => account.listp_path)
  end

  def update_archive
    reply(:empty_fields, :account_archive) +
        reply(:update_silent, :account_archive => [[0, "Actual"]].concat(
            if archive = AccountRoot.archive
              archive.accounts.collect { |a|
                [a.id, a.path] }.sort_by { |a| a[1] }
            else
              []
            end))
  end

  def rpc_update_view(session)
    super(session) +
        update_list +
        update_archive
  end

  def rpc_list_choice_account_list(session, data)
    reply(:empty_fields) +
        if (acc = data._account_list) != []
          reply(:update, {total: acc.total_form,
                          desc: acc.desc,
                          name: acc.name})
        else
          []
        end
  end

  def rpc_list_choice_account_archive(session, data)
    update_list(data._account_archive)
  end
end
