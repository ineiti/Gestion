class TaskGroup < View
  def layout
    gui_vbox :nogroup do
      show_button :new_task
    end
  end
end