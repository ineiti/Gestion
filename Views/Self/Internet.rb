class SelfInternet < View
  def layout
    set_data_class :Persons
    @order = 10

    gui_vbox do
      show_int_ro :credit
      show_button :connect, :disconnect
    end

    @order = 10
#    @visible = false
  end

  def rpc_show( session )
    super( session ) +
      reply( :update, update( session ) ) +
      reply( :hide, :disconnect )
  end

  def rpc_button_connect( session, data )
    reply( :hide, :connect ) +
    reply( :unhide, :disconnect )
  end

  def rpc_button_disconnect( session, data )
    reply( :hide, :disconnect ) +
    reply( :unhide, :connect )
  end
end
