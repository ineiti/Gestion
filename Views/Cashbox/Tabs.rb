# To change this template, choose Tools | Templates
# and open the template in the editor.

class CashboxTabs < View
  def layout
    @order = 90
    @functions_need = [:cashbox, :accounting_courses]
  end
  
end
