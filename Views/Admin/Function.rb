class AdminFunction < View
  def layout
    @order = 10
    @update = true
    @func = Entities.Statics.get( :AdminFunction )
    if @func.data_str.class != Hash
      @func.data_str = {}
    end

    gui_hbox do
      show_list :usage, "View.AdminFunction.list_usage"
      show_button :save
    end
  end
  
  def rpc_update( session )
    reply( :empty ) +
      reply( :update, :usage => @func.data_str )
  end
  
  def rpc_button_save( session, data )
    @func.data_str = data[ "usage" ]
  end
  
  def list_usage
    [ [ 1, :gateway ],[ 2, :share ],[ 3, :courses ], [ 4, :inventory ] ]
  end
end