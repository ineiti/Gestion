# Manages grades of a course
# - Add or change grades
# - Print out grades

class CourseGrade < View
  def layout
    set_data_class :Courses
    
    gui_hbox do
      gui_hbox do
        gui_fields do
          show_list_single :courses, "Entities.Courses.list_courses", :callback => true
        end
        gui_fields do
          show_list_single :students, :callback => true
        end
        gui_fields do
          show_int :mean
          show_str :remark
          show_str :first_name
          show_str :family_name
          show_button :save
        end
      end
    end
  end
  
  def update_grade( d )
    ret = []
    c_name, p_name = d['courses'][0], d['students'][0]
    if p_name and c_name
      grade = Entities.Grades.find_by_course_person( c_name, p_name )
      if grade
        ret = reply( "update", grade.to_hash )
      else
        ret = reply( "empty" )
      end
      ret += reply( "update", Entities.Persons.find_by_login_name( p_name ).to_hash )
    end
    ret
  end
  
  def rpc_list_choice( sid, name, args )
    dputs 3, "rpc_list_choice with #{name} - #{args.inspect}"
    ret = reply('empty')
    case name
    when "courses"
      course_id = args['courses'][0]
      course = @data_class.find_by_course_id(course_id).to_hash
      dputs 3, "replying"
      ret = reply("empty", [:students]) +
      reply("update", course ) +
      reply("update", {:courses => [course_id]}) +
      reply("focus", :mean)
      if course[:students].size > 0
        ret += reply("update", {:students => [course[:students][0][0]]} )
      end
    when "students"
      ret += update_grade( args )
    end
    ret
  end
  
  def rpc_button_save( sid, data )
    dputs 3, "Data is #{data.inspect}"
    course = @data_class.find_by_course_id( data['courses'][0])
    student = Entities.Persons.find_by_login_name( data['students'][0])
    if course and student
      Entities.Grades.save_data( {:course_id => course.course_id,
        :person_id => student.person_id, :mean => data['mean'], 
        :remark => data['remark']})
      if data['first_name']
        Entities.Persons.save_data({:person_id => student.person_id,
      :first_name => data['first_name'], :family_name => data['family_name']})
      end

      # Find next student
      course = course.to_hash
      saved = course[:students].index{|i|
        i[0] == data['students'][0]
      }
      dputs 2, "Found student at #{saved}"
      data['students'] = course[:students][( saved + 1 ) % course[:students].size]
      dputs 2, "Next student is #{data['students'].inspect}"
      
      reply( "empty" ) +
      update_grade( data ) + 
      reply( 'update', {:students => [data['students'][0]] } ) + 
      reply( 'focus', :mean )
    end
  end
  
end
