class LibraryPerson < View
  def layout
    @order = 100
    @update = true

    gui_hboxg do
      gui_vboxg :nogroup do
        show_entity_person :users, :single, :to_list_id,
                                :callback => true, :flexheight => 1
      end
      gui_vboxg :nogroup do
        show_block :address, :flexwidth => 1
        show_button :save
      end
    end
  end

  def library_users
    Activities.tagged_users('library').to_frontend
  end

  def rpc_update(session)
    reply(:empty, :users) +
        reply(:update, users: library_users )
  end

  def rpc_list_choice_users(session, data)
    dp reply(:empty_fields) +
        reply(:update, data._users.to_hash)
  end

  def rpc_button_save(session, data)
    return unless data._users
    data._users.data_set_hash(data)
  end
end