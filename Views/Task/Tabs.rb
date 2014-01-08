class TaskTabs < View
  def layout
    @visible = false
    
    gui_vbox :nogroup do
      show_button :new_task
    end
  end
end