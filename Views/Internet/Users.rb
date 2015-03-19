class InternetUsers < View
  def layout
    @order = 50

    gui_hbox do
      gui_vbox do
        show_str :search
        show_entity_person :persons, :single, :login_name
        show_button :add
      end
      gui_vbox do
        show_entity_internetClass :iclass, :drop, :name
      end
    end
  end
end