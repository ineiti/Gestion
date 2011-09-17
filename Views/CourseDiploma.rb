=begin
  Shows the existing courses and the courses on the server, so that the
  two can be synchronized.
=end

class CourseDiploma < View
  def layout
    set_data_class :Courses
    
    gui_hbox do
      gui_vbox :nogroup do
        show_list_single :local, "Entities.Courses.list_courses"
      end
      gui_vbox do
        show_button :to_grade
        show_button :from_grade
      end
      gui_vbox :nogroup do
        show_list_single :grade, "View.CourseDiploma.list_grade"
      end
    end
  end
  
  def list_grade
    %w( base_0401 base_0402 base_0403 )
  end
  
  def rpc_button_to_grade( sid, data )
    local = data['local']
    return if local.size == 0
    course = Entities.Courses.find_by_course_id( local )
    dputs 0, "Data is: #{course.inspect}"
    course.export_to_diploma
  end
end