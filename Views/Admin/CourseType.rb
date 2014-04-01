# To change this template, choose Tools | Templates
# and open the template in the editor.

class AdminCourseType < View
  include VTListPane
  
  def layout
    set_data_class :CourseTypes
    
    @functions_need = [:courses]
    
    gui_hboxg do
      gui_vboxg :nogroup do
        vtlp_list :ctype, 'name', :flexheight => 1
        show_button :new, :delete
      end
      
      gui_vboxg do
        gui_hboxg :nogroup do
          gui_vboxg :nogroup do
            show_block :strings
            show_block :accounting
          end
          gui_vboxg :nogroup do
            show_block :central
          end
        end
        gui_vboxg :nogroup do
          show_block :long, :width => 200
          show_field :page_format
          show_list_drop :filename, 'CourseTypes.files'
        end
        show_button :save        
      end
    end
  end
end
