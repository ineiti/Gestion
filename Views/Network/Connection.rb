class NetworkConnection < View
  def layout
    @update = true
    @functions_need = [:internet]

    gui_vbox do
      show_str_ro :connection
      show_int :cost_base
      show_int :cost_shared
      show_list_drop :allow_free, "%w( true false )"
      show_button :save_costs
    end
  end

  def rpc_button_save_costs( session, data )
    $lib_net.call_args( :isp_cost_set, "#{data['cost_base']} #{data['cost_shared']}" )
    $lib_net.call_args( :isp_free_set, data['allow_free'][0] )
  end

  def update( session )
    { :connection => $lib_net.print( :ISP ),
      :allow_free => [$lib_net.print( :ALLOW_FREE )],
      :cost_base => $lib_net.print( :COST_BASE ),
      :cost_shared => $lib_net.print( :COST_SHARED ) }
  end
end
