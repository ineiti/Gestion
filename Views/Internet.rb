class Internet < View
  def layout
    set_data_class :Persons

    gui_vbox do
      show_int_ro :credit
      show_button :connect, :disconnect
    end

#    @order = 100
#    @visible = false
  end

  def rpc_show( session )
    super( session ) + [{ :cmd => "update", :data => update( session )}] +
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
