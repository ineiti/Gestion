class InventoryTabs < View
  def layout
    @order = 40
    @functions_need = [:inventory]

    gui_vboxg :nogroup do
    end
  end
end