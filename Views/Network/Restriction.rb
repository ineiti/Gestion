class NetworkRestriction < View
  def layout
    @update = true
    @functions_need = [:internet]

    gui_vbox do
      show_html :state
      show_button :remove_restriction, :restrict_info1, :restrict_info2
    end
  end

  def rpc_update( session )
    restricted = Captive.restriction
    if restricted.length > 0
      reply( :update, :state => "Restricted internet, only allowed for:<br><pre>#{ restricted }</pre>" )
    else
      reply( :update, :state => 'No restriction in place')
    end
  end

  def rpc_button_remove_restriction( session, args )
    Captive.restriction_set( nil )
    rpc_update( session )
  end

  def rpc_button_restrict_info1( session, args )
    Captive.restriction_set 'info1'
    rpc_update( session )
  end

  def rpc_button_restrict_info2( session, args )
    Captive.restriction_set 'info2'
    rpc_update( session )
  end
end
