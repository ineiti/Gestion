# To change this template, choose Tools | Templates
# and open the template in the editor.

class ComptaShow < View
	include VTListPane
  def layout
		set_data_class :Accounts
		gui_hbox do
			gui_vbox do
				vtlp_list :account_list, 'path', :width => 150
			end
			gui_vbox do
				show_int :total
			end
		end
  end
end
