class AdminBlock < View
  def layout
    @order = 1
    @pcs = 2
    @blocking = Entities.Statics.get( :AdminBlock )

    gui_hbox do
      gui_vbox :nogroup do
        show_list :blocked, "View.AdminBlock.list_dhcp"
        show_button :block
      end
    end
  end

  def list_dhcp
    @pcs += 1
    1.upto(@pcs).collect{|pc| "pc#{pc}" }
  end
  
  def rpc_update_view( session )
    super( session ) +
    reply( :update, :blocked => @blocking.data_str )
  end

  def rpc_button_block( session, data )
    @blocking.data_str = data['blocked']
  end
end
