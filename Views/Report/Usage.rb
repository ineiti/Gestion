class ReportUsage < View

  def layout
    @order = 60
    @update = true
    @functions_needed = [ :usage_report ]

    gui_hbox do
      gui_vbox :nogroup do
        show_entity_usage :usage, :single, :name, :callback => true
        show_button :print
      end
      gui_vbox :nogroup do
        show_table :usage_report, :headings => [ :Date, :Element, :Count ]
        show_date :from
        show_date :to
        show_button :update
      end
    end
  end

  def rpc_update( session )
    reply( :update, {from: Date.today.to_web, to: Date.today.to_web})
  end

  def rpc_print(session, name, data)

  end

  def rpc_list_choice_usage(session, data)

  end
end