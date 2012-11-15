class AdminBlock < View
  def layout
    if not $lib_net
      @visible = false
      return
    end

    @order = 100
    @blocking = Entities.Statics.get( :AdminBlock )
    update_block( @blocking.data_str )

    gui_hbox do
      gui_vbox :nogroup do
        show_list :blocked, "View.AdminBlock.list_dhcp", :width => 400
        show_button :block
      end
    end
  end

  def update_block( ips )
    $lib_net.call_args( :captive_block, ips.collect{|ip| ip.sub(/ .*/,'') } )
  end

  def list_dhcp
    `cut -d " " -f 3,4 /var/lib/misc/dnsmasq.leases`.split("\n")
  end
  
  def rpc_update_view( session )
    super( session ) +
    reply( :update, :blocked => @blocking.data_str )
  end

  def rpc_button_block( session, data )
    update_block( @blocking.data_str = data['blocked'] )
  end
end
