class InventoryTicketOpen < View
  include VTListPane
  include TicketLayout
  def layout
    t_layout( :opened )
  end
  
  def rpc_button_save_ticket( session, data )
    if not data['created_by']
      data['created_by'] = session.owner.full_name
    end
    rpc_button_save( session, data )
  end
  
  def rpc_update( session )
    reply( :update, :created_by => session.owner.full_name )    
  end
  
  def rpc_button_new_ticket( session, data )
    rpc_button_new( session, data ) +
      rpc_update( session )
  end
end
