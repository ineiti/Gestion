class SpecialDFileEdit < View
  def layout
    @order = 100
    @functions_need = [:files_manage]

    gui_hbox do
      gui_vbox do
        show_button :mount_harddisk
        show_button :contact_url
      end
    end
  end
end