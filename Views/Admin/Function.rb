class AdminFunction < View
  def layout
    @order = 400
    @update = true
    set_data_class( :ConfigBases )

    gui_vboxg do
      show_block :default
      show_arg :functions, :flexheight => 1
      show_button :save
    end
  end
  
  def rpc_update( session )
    reply( :empty ) +
      update_form_data( ConfigBases.singleton )
  end
  
  def rpc_button_save( session, data )
    ConfigBase.store( data.to_sym )
    dputs(3){"Configuration is now #{ConfigBase.get_functions.inspect}"}
    
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