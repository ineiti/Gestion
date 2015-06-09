# Manages grades of a course
# - Add or change grades
# - Print out grades

class CourseStudents < View
  def layout
    set_data_class :Courses

    @update = true
    @order = 30

    gui_hboxg do
      gui_vboxg :nogroup do
        show_list_single :students, :width => 300, :callback => true, :flexheight => 1
      end
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_str :first_name, :width => 150
          show_str :family_name
          show_list_drop :gender, '%w( male female n/a )'
          show_button :save
        end
      end
    end
  end

  def rpc_update(session)
    super(session) +
        reply(:empty_nonlists, [:students])
  end

  def update_student(data)
    c_id, p_name = data._courses[0], data._students[0]
    if p_name and c_id
      person = Persons.match_by_login_name(p_name)
      update_form_data(person)
    else
      []
    end
  end

  def rpc_list_choice(session, name, data, select = nil)
    dputs(3) { "rpc_list_choice with #{name} - #{data.inspect}" }
    ret = []
    course_id = data._courses[0]
    course = Courses.match_by_course_id(course_id)
    case name
      when 'courses'
        if course
          dputs(3) { 'replying' }
          ret = rpc_update(session) +
              reply(:empty_nonlists, :students) +
              update_form_data(course) +
              reply(:update, {:courses => [course_id]})
          ls = course.list_students
          if course.students.size > 0 && ls.size > 0
            first = if select
                      # Fetch the next element, first one if it was the last one
                      ls[((0...ls.length).find{ |i|
                           ls[i][0] == select
                         }.to_i + 1) % ls.length][0]
                    else
                      course.list_students[0][0]
                    end
            ret += reply(:update, {:students => [first]})
          end

          dputs(4) { "Course is #{course} - ret is #{ret.inspect}" }
        end
      when 'students'
        ret += update_student(data)
    end

    ret
  end

  def rpc_button_save(session, data)
    dputs(3) { "Data is #{data.inspect}" }
    c_id, p_name = data._courses.first, data._students.first
    course = Courses.match_by_course_id(c_id)
    student = Entities.Persons.match_by_login_name(p_name)
    if course and student
      if data._first_name
        Entities.Persons.save_data({:person_id => student.person_id,
                                    :first_name => data._first_name,
                                    :family_name => data._family_name,
                                    :gender => data._gender})
      end
      rpc_list_choice(session, 'courses', data, p_name)
    end
  end
end
