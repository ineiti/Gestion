class AdminAccess < View
  def layout
    @update = true

    gui_vbox do
      show_html :state
      show_button :unblock, :block_info1, :block_info2
    end
  end

  def rpc_update( session )
    dputs 0, "rpc_update"
    blocked = %x[ cat /var/run/captive/block ]
    if blocked.length > 0
      reply( 'update', :state => "Blocked internet, only allowed for:<br><pre>#{ blocked }</pre>" )
    else
      reply( 'update', :state => "No block in place" )
    end
  end

  def rpc_button_unblock( session, args )
    %x[ /var/www/internet/lib block_delete ]
    rpc_update( session )
  end

  def rpc_button_block_info1( session, args )
    %x[ /var/www/internet/lib block_set info1 ]
    rpc_update( session )
  end

  def rpc_button_block_info2( session, args )
    %x[ /var/www/internet/lib block_set info2 ]
    rpc_update( session )
  end
end
