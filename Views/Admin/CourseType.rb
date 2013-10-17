# To change this template, choose Tools | Templates
# and open the template in the editor.

class AdminCourseType < View
  include VTListPane
  
  def layout
    set_data_class :CourseTypes
    
    @functions_need = [:courses]
    
    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :ctype, 'name'
        show_button :new, :delete
      end
      
      gui_vbox do
        gui_hbox :nogroup do
          gui_vbox :nogroup do
            show_block :strings
          end
          gui_vbox :nogroup do
            show_block :central
          end
        end
        gui_vbox :nogroup do
          show_block :long, :width => 200
          show_field :page_format
          show_list_drop :filename, 'CourseTypes.files'
        end
        show_button :save        
      end
    end
  end
end
