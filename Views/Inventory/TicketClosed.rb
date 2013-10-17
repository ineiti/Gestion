class InventoryTicketClosed < View
  include VTListPane
  include TicketLayout
  def layout
    t_layout( :closed )
  end
end
