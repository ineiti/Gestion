# To change this template, choose Tools | Templates
# and open the template in the editor.

class AdminCourseType < View
  include VTListPane
  
  def layout
    set_data_class :CourseTypes
    
    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :ctype, 'name'
        show_button :new, :delete
      end
      
      gui_vbox :nogroup do
        show_block :strings, :width => 200
        show_list_drop :filename, 'CourseTypes.files'
        
        show_button :save
      end
    end
  end
end
