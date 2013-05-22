class AdminFunction < View
  def layout
    @order = 10
    @update = true
    set_data_class( :ConfigBases )

    gui_hbox do
      show_block :default
      #show_list :functions, "ConfigBases.list_functions"
      #show_value :isp
      show_button :save
    end
  end
  
  def rpc_update( session )
    reply( :empty ) +
      reply( :update, ConfigBases.singleton.to_hash )
  end
  
  def rpc_button_save( session, data )
    ConfigBase.store( data.to_sym )
    ddputs(3){"Configuration is now #{ConfigBase.get_functions.inspect}"}
    
    rpc_update( session )
  end
  
  def list_usage
    index = 0
    @@usages.collect{|c|
      index += 1
      [ index, c.to_sym ]
    }
  end
end