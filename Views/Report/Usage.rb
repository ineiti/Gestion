class ReportUsage < View

  def layout
    @order = 60
    @update = true
    @functions_needed = [:usage_report]

    gui_hbox do
      gui_vbox :nogroup do
        show_entity_usage :usage, :single, :name, :callback => true
        show_button :print
      end
      gui_vbox :nogroup do
        show_table :usage_report, :headings => [:Element, :Count],
                   :widths => [300, 70], :height => 300
        show_list_drop :duration, '[[1, :day],[7, :week], [14, :bi_week],' +
            ' [31,:month], [365, :year]]', :callback => true
        show_date :from
        show_date :to
        show_button :update
      end
    end
  end

  def rpc_update(session)
    reply(:update, {from: (Date.today - 7).to_web, to: Date.today.to_web,
                    duration: [7]})
  end

  def rpc_print(session, name, data)

  end

  def rpc_list_choice_usage(session, data)
    return [] unless data._usage
    table = data._usage.collect_data(data._from.date_from_web,
                                     data._to.date_from_web)
    reply(:empty_only, :usage_report) +
        reply(:update, {:usage_report => table,
                        from: data._from, to: data._to})
  end

  def rpc_list_choice_duration(session, data)
    return [] if !data._to or !data._duration.first or !data._usage
    dp data._duration
    data._from = (data._to.date_from_web - data._duration.first.to_i).to_web
    rpc_list_choice_usage(session, data)
  end

  def rpc_button_update(session, data)
    rpc_list_choice_usage(session, data)
  end
end