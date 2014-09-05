class ReportUsage < View

  def layout
    @order = 60

    gui_vbox do
      show_entity_usage :usage, :single, :name, :callback => true
      show_button :print
    end
  end

  def rpc_print( session, name, data )

  end
end