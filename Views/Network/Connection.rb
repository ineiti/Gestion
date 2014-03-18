class NetworkConnection < View
  def layout
    @update = true
    @functions_need = [:internet]
    @multiconf = %w( PREROUTING HTTP_PROXY ALLOW_DST INTERNAL_IPS
        CAPTIVE_DNAT OPENVPN_ALLOW_DOUBLE ALLOW_SRC_DIRECT ALLOW_SRC_PROXY)

    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_list_drop :connection, "%w( simul )"
          show_int :cost_base
          show_int :cost_shared
          show_list_drop :allow_free, "%w( true false all )"
        end
        gui_vbox :nogroup do
          @multiconf.each{|m| show_str m.capitalize }
        end
      end
      show_button :save_costs
    end
  end

  def rpc_button_save_costs( session, data )
    $lib_net.call( :isp_cost_set, "#{data._cost_base} #{data._cost_shared}" )
    $lib_net.call( :isp_free_set, data._allow_free )
    $lib_net.call( :isp_set, data._connection )
    $lib_net.call( :set_multiconf, @multiconf.map{|m| 
        "#{m.upcase}=#{data[m.capitalize]}"}.join( " " ) )
    $lib_net.call( :captive_setup )
  end

  def update( session )
    { :connection => [$lib_net.print( :ISP )],
      :allow_free => [$lib_net.print( :ALLOW_FREE )],
      :cost_base => $lib_net.print( :COST_BASE ),
      :cost_shared => $lib_net.print( :COST_SHARED ) }.merge(
      @multiconf.map{|m| [m, $lib_net.print( m )]}.to_h )
  end
  
  def rpc_update( session )
    isps = /^.(.*).$/.match( $lib_net.print(:ISPs) )[1].split
    dputs(3){"ISPs is #{isps}"}
    reply( :empty_only, :connection ) +
      reply( :update, :connection => isps ) +
      super
  end
end
