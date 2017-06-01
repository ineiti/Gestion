# Manages grades of a course
# - Add or change grades
# - Print out grades

class CourseGrade < View
  def layout
    set_data_class :Courses

    @update = true
    @order = 20

    #    gui_vboxgl do
    gui_hboxg do
      gui_vboxg :nogroup do
        show_table :students, headings: %w(Name Grade Files Status),
                   widths: [250, 40, 40, 50], callback: :click,
                   height: 350, width: 390, single: true
        #show_list_single :students, :width => 300, :callback => true, :flexheight => 1
        show_str_ro :last_synched
        show_button :prepare_files, :fetch_files, :transfer_files, :sync_server
      end
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_str :first_name, :width => 150
          show_str :family_name
          show_list_drop :gender, '%w( male female n/a )'
          show_int_ro :files_saved
          show_str :remark
          show_table :grades, :headings => %w(Label grade), :widths => [150, 50],
                     :columns => %w(0 align_right), :callback => :edit,
                     :edit => [1], :height => 200
        end
        gui_vbox :nogroup do
          show_html :name_file_direct
          show_upload :upload_direct, :callback => true
          show_button :save, :upload
        end
      end
      gui_window :transfer do
        show_html :txt
        show_upload :files
        show_button :close
      end

      gui_window :sync do
        show_html :synching
        show_button :close
      end

      gui_window :upload_files do
        show_html :name_file_1
        show_upload :upload_file_1, :callback => true
        show_html :name_file_2
        show_upload :upload_file_2, :callback => true
        show_html :name_file_3
        show_upload :upload_file_3, :callback => true
        show_html :name_file_4
        show_upload :upload_file_4, :callback => true
        show_html :name_file_5
        show_upload :upload_file_5, :callback => true
        show_button :close
      end
    end
  end

  def rpc_update(session)
    super(session) +
        reply(:empty_nonlists, [:students]) +
        [:prepare_files, :fetch_files, :transfer_files,
         :last_synched, :sync_server, :upload, :files_saved,
         :upload_direct, :name_file_direct, :remark].collect { |b|
          reply(:hide, b)
        }.flatten
  end

  def update_files_saved(course, student)
    reply(:update, :files_saved =>
                     "#{course.exam_files(student).count}/#{course.ctype.files_nbr}")
  end

  def get_grades(ct, grades)
    means = grades ? grades.means : [''] * ct.tests_nbr.to_i
    i = 0
    ct.tests_arr.zip(means).collect { |t, m|
      [i += 1, [t, m.to_s]]
    }
  end

  def update_grade(data)
    c_id, p_name = data._courses[0], data._students[0]
    if p_name and c_id
      person = Persons.match_by_login_name(p_name)
      course = Courses.match_by_course_id(c_id)
      grade = Entities.Grades.match_by_course_person(c_id, p_name)
      reply(:update, :grades => get_grades(course.ctype, grade)) +
          reply(:empty_update, :remark => (grade ? grade.remark : ''))+
          update_form_data(person) +
          update_files_saved(course, p_name)
    else
      []
    end
  end

  def update_students_table(course)
    reply_table_columns_visible(course.ctype.files_nbr.to_i > 0, students: [2]) +
        reply_table_columns_visible(course.ctype.diploma_type == %w(accredited),
                                    students: [3]) +
        reply(:update,
              students:
                  course.students.collect { |s|
                    if person = Persons.match_by_login_name(s)
                      mean, random = if grade = Grades.match_by_course_person(course, person)
                                       [grade.mean, grade.random]
                                     else
                                       ['--', nil]
                                     end
                      [s, [person.full_name, mean, course.exam_files(person).length,
                           random ? 'OK' : 'do_sync']]
                    end
                  }.compact.sort_by { |a, b| b[0] })
  end

  def rpc_list_choice(session, name, data)
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
              reply(:update, courses: [course_id]) +
              update_students_table(course)

          dputs(3) { "CType is #{course.ctype.inspect} - #{course.ctype.files_nbr.inspect}" }
          buttons = []
          if (nbr = course.ctype.files_nbr.to_i) > 0
            dputs(3) { 'Putting buttons' }
            buttons.push :transfer_files, :files_saved
            buttons.push(if nbr > 1
                           :upload
                         else
                           ret += reply(:update,
                                        upload_direct: course.ctype.files_arr.first) +
                               reply(:update, name_file_direct: 'chose student')
                           [:upload_direct, :name_file_direct]
                         end)
            if Shares.match_by_name('CourseFiles')
              buttons.push :prepare_files, :fetch_files
            end
          end
          if course.students.size > 0 && course.list_students.size > 0
            first = course.list_students[0][0]
            ret += reply(:select, students: [first]) +
                rpc_table_students(session, data.merge(students: [first]))
          end
          if course.ctype.diploma_type[0] == 'accredited' and
              ConfigBase.has_function?(:course_client)
            buttons.push :sync_server
          end
          buttons.each { |b|
            ret += reply(:unhide, b)
          }
          ret += reply_visible(course.ctype.remark.to_s == '[true]', :remark)

          dputs(4) { "Course is #{course} - ret is #{ret.inspect}" }
        end
    end

    ret
  end

  def rpc_button_save(session, data)
    dputs(3) { "Data is #{data.inspect}" }
    c_id, p_name = data._courses.first, data._students.first
    course = Courses.match_by_course_id(c_id)
    student = Entities.Persons.match_by_login_name(p_name)
    grade = Entities.Grades.match_by_course_person(c_id, p_name)
    if course and student
      means = new_grades(course.ctype, grade, data._grades.first)
      Entities.Grades.save_data({:course => course,
                                 :student => student,
                                 :means => means,
                                 :remark => data._remark})
      log_msg :grades, "#{session.owner.login_name} added grades #{means.inspect} " +
                         "to #{student.login_name} from #{course.name} with remark -#{data._remark}-"
      if data._first_name
        Entities.Persons.save_data({:person_id => student.person_id,
                                    :first_name => data._first_name,
                                    :family_name => data._family_name,
                                    :gender => data._gender})
      end

      grades = data._grades.first
      element = grades ? grades._element_id.to_i : 0

      update_students_table(course) +
          if element >= course.ctype.tests_nbr.to_i
            # Find next student
            course = course.to_hash
            if saved = course[:students].index { |i|
              i[0] == data._students[0]
            }
              dputs(3) { "Found student at #{saved}" }
              data._students = course[:students][(saved + 1) % course[:students].size]
              dputs(3) { "Next student is #{data._students.inspect}" }
              reply(:select, students: [data._students[0]]) +
                  rpc_table_students(session, data)
            else
              []
            end
          else
            update_grade(data) +
                reply(:focus, {table: 'grades', row: element, col: 1}) +
                reply(:select, students: [data._students[0]])
          end
    end
  end

  def rpc_button_transfer_files(session, data)
    ret = reply(:update, :txt => 'no students') +
        reply(:hide, :upload)
    if course = Courses.match_by_course_id(data._courses[0])
      if file = course.zip_create
        ret = reply(:update, :txt => 'Download skeleton: ' +
                               "<a target='other' href='/tmp/#{file}'>#{file}</a>") +
            reply(:unhide, :upload)
      end
    end
    reply(:window_show, :transfer) +
        ret
  end

  def rpc_button_prepare_files(session, data)
    if course = Courses.match_by_course_id(data._courses[0])
      course.exas_prepare_files
    end
    update_grade(data)
  end

  def rpc_button_fetch_files(session, data)
    if course = Courses.match_by_course_id(data._courses[0])
      course.exas_fetch_files
    end
    update_grade(data)
  end

  def rpc_button_close(session, data)
    if course = Courses.match_by_course_id(data._courses[0])
      course.zip_read
      reply(:window_hide) +
          update_grade(data) +
          reply(:auto_update, 0)
    end
  end

  def rpc_update_with_values(session, data)
    ret = []
    if course = Courses.match_by_course_id(data._courses[0])
      ret = reply(:update, :synching => 'Sync-state:<ul>' + course.sync_state)
      if course.sync_state =~ /(finished|Error:)/
        ret += reply(:auto_update, 0) +
            update_students_table(course)
      end
    end
    ret
  end

  def rpc_button_sync_server(session, data)
    log_msg :grade, 'Syncing with server'
    if course = Courses.match_by_course_id(data._courses[0])
      course.sync_start

      reply(:window_show, :sync) +
          reply(:auto_update, -1) +
          rpc_update_with_values(session, data)
    else
      reply(:window_show, :sync) +
          reply(:update, :synching => 'Please chose a course first')
    end
  end

  def rpc_button_upload(session, data, window_show = true)
    data.to_sym!
    course = Courses.match_by_course_id(data._courses[0])
    student = Persons.match_by_login_name(data._students[0])
    ctype = course.ctype
    files_nbr = ctype.files_nbr.to_i
    exam_files = course.exam_files(student)
    dputs(3) { "Exam-files = #{exam_files.inspect}" }
    ret = window_show ? reply(:window_show, :upload_files) : []
    ret + (1..5).collect { |i|
      show = :hide
      ret = []
      if i <= files_nbr
        show = :unhide
        file_nb = exam_files.index { |f| f =~ /^#{i}-/ }
        file = file_nb ? exam_files[file_nb] : ''
        ret += reply(:update, "name_file_#{i}" =>
                                "file ##{i}: #{exam_file_to_href(course, student, file)}") +
            reply(:update, "upload_file_#{i}" => ctype.files_arr[i-1])
      end
      dputs(3) { "Return is #{ret.inspect}" }
      ret +
          reply(show, "name_file_#{i}") +
          reply(show, "upload_file_#{i}")
    }.flatten
  end

  def rpc_button(session, name, data)
    if name =~ /^upload_file_/
      number = name.sub(/.*_/, '').to_i

      data.to_sym!
      course = Courses.match_by_course_id(data._courses[0])
      student = data._students[0]
      dputs(4) { "Course is #{course} - filename is #{data._filename} " +
          "student is #{student}" }
      if course and student and data._filename
        files_nbr = course.ctype.files_nbr.to_i

        course.check_students_dir
        filename = UploadFiles.escape_chars(data._filename)
        src = "/tmp/#{filename}"
        dst = "#{Courses.dir_exams}/#{course.name}/#{student}"
        dputs(3) { "Moving #{src} to #{dst}" }
        FileUtils.rm Dir.glob("#{dst}/#{number}-*")
        FileUtils.mv src, "#{dst}/#{number}-#{filename}"

        ret = rpc_button_upload(session, data, false) +
            update_files_saved(course, student)
        if (number == files_nbr) and
            (files_nbr == course.exam_files(student).count)
          ret += reply(:window_hide) + rpc_button_save(session, data)
        end
        dputs(3) { "Return is #{ret.inspect}" }
        return ret
      end
    else
      return super(session, name, data)
    end
  end

  def new_grades(ct, grade, new_grades)
    return [] unless new_grades
    means = grade ? grade.means : []
    i = 0
    ct.tests_arr.zip(means).collect { |t, m|
      i+= 1
      if i == new_grades._element_id.to_i then
        new_grades._grade.sub(/,/, '.').to_f
      else
        m ? m : 0
      end
    }
  end

  def rpc_table_grades(session, data)
    c_id, p_name = data._courses.first, data._students.first
    course = Courses.match_by_course_id(c_id)
    student = Entities.Persons.match_by_login_name(p_name)
    grade = Entities.Grades.match_by_course_person(c_id, p_name)
    return unless grades = data._grades.first
    return unless element = grades._element_id.to_i

    if course and student
      means = new_grades(course.ctype, grade, grades)
      Entities.Grades.save_data({:course => course,
                                 :student => student,
                                 :means => means,
                                 :remark => data._remark})
    end
    if element == course.ctype.tests_nbr.to_i
      rpc_button_save(session, data)
    else
      reply(:focus, {table: 'grades', row: element, col: 1})
    end
  end

  def rpc_table_students(session, data)
    course_id = data._courses[0]
    course = Courses.match_by_course_id(course_id)
    student = Entities.Persons.match_by_login_name(data._students.first)
    file = course.exam_files(student).first
    reply(:update, name_file_direct: exam_file_to_href(course, student, file)) +
        update_grade(data) +
        reply(:focus, {table: 'grades', col: 1, row: 0})
  end

  def rpc_button_upload_direct(session, data)
    rpc_button(session, 'upload_file_1', data)
  end


  def exam_file_to_href(course, student, file)
    dst = "#{course.name}/#{student.login_name}"
    file ? "<a href='/exas/#{dst}/#{file}' target='_blank'>#{file}</a>" : 'Upload file'
  end
end
