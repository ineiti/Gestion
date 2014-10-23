class AdminScheduleType < View
  #include VTListPane

  def layout
    @order=350
    @update = true

    gui_hboxg do
      #gui_vboxg :nogroup do
        #vtlp_list :stype, :name, :flexheight => 1
        #show_button :new, :delete
      #end
      gui_vboxg :nogroup do
        show_html :choice, :flex => 1
        show_button :save, :render
      end
    end
  end

  def rpc_update(session)
    reply(:update, :choice => ScheduleTypes.get_html) +
        reply(:eval, ScheduleTypes.get_script)
  end

  def rpc_button_render(session, data)
    reply(:eval, 'add_days();add_hours();')
  end
end