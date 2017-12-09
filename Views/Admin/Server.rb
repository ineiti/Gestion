class AdminServer < View
  def layout
    @functions_need = [:course_client]
    @order = 300

    gui_vbox do
      show_button :import_ctypes
      show_button :import_courses

      gui_window :win_import do
        show_html :status
        show_list :import_list
        show_button :download, :close
      end
    end
  end

  def check_availability(t)
    if ConfigBase.server_url.to_s.length == 0
      [false, 'No server defined, aborting']
    else
      if Persons.center
        [true, "Fetching #{t} from server"]
      else
        [false, 'There is no center defined, aborting']
      end
    end
  end

  def status_list(show_status, status: '', list: [])
    reply_one_two(show_status, :close, :download) +
        reply_one_two(show_status, :status, :import_list) +
        if show_status
          reply(:update, status: status)
        else
          reply(:empty, :import_list) + reply(:update, import_list: list)
        end
  end

  def rpc_button_import_ctypes(session, data)
    ms = MakeSteps.new(session, -1) { |session, data, step|
      case step
        when 0
          ms.auto_update = -1
          downloading, status = check_availability(:CourseTypes)
          reply(:window_show, :win_import) +
              if downloading
                status_list(true, status: status)
              else
                ms.step = 3
                status_list(true, status: "Error: #{status}")
              end
        when 1
          res = ICC.get(:CourseTypes, :list)
          if res._code == 'Error'
            ms.step = 3
            status_list(true, status: "Error: #{res._msg}")
          else
            ms.auto_update = 0
            status_list(false, list: res._msg)
          end
        when 2
          ms.auto_update = -1
          if (cts_names = data._import_list).length == 0
            log_msg :CourseType, 'Nothing to download'
            status_list(true, status: 'Nothing to download')
          else
            ms.status = status_list(true, status: "Downloading #{cts_names.length} CourseTypes")
            data._import_list.each { |ct|
              get_ctype(ct, ms)
            }
            ms.auto_update = 0
            status_list(true, status: "Downloaded #{cts_names.length} CourseTypes")
          end
        when 3
          ms.auto_update = 0
          reply(:window_hide)
      end
    }

    ms.make_step(session, data)
  end

  def get_ctype(name, ms)
    ms.status = status_list(true, status: "Downloading CourseType #{name}")
    cts = ICC.get(:CourseTypes, :fetch,
                  args: {course_type_names: name.to_a})
    if cts._code == 'Error'
      raise StandardError(cts._msg)
    end

    log_msg :CourseType, "Downloaded #{name}"
    ct = cts._msg.first
    ct = if ct_exist = CourseTypes.match_by_name(ct._name)
           log_msg :CourseType, "Updating CourseType #{ct._name}"
           ct_exist.data_set_hash(ct)
         else
           log_msg :CourseType, "Creating CourseType #{ct._name}"
           CourseTypes.create(ct)
         end
    [ct._file_diploma, ct._file_exam].compact.each { |f|
      file = f.first
      if file.length > 0
        ms.status = status_list(true, status: "Downloading file #{file}")
        rep = ICC.get(:CourseTypes, :_file, args: {name: [file]})
        if rep._code == 'OK'
          data = rep._msg
          log_msg :CourseType, "Got file #{file} with length #{data.length}"
          IO.write("#{ConfigBase.template_dir}/#{file}", data)
        else
          log_msg :CourseType, "Got error #{rep._msg}"
        end
      end
    }
    ct
  end

  def rpc_update_with_values(session, data)
    MakeSteps.make_step(session, data)
  end

  def rpc_button_download(session, data)
    MakeSteps.make_step(session, data)
  end

  def get_person(name, ms)
    if p = Persons.match_by_login_name(name)
      return p
    end
    ms.status = status_list(true, status: "Fetching person #{name}")
    person = ICC.get(:Persons, :get, args: {center: Persons.center, name: [name]})
    if person._code == 'Error'
      raise StandardError(person._msg)
    end
    Persons.create(person._msg.to_sym)
  end

  def rpc_button_import_courses(session, data)
    ms = MakeSteps.new(session, -1) { |session, data, step|
      # dputs_func
      case step
        when 0
          ms.auto_update = -1
          downloading, status = check_availability(:Courses)
          ms.step = (downloading ? 1 : 10)
          reply(:window_show, :win_import) +
              status_list(true, status: status)
        when 1
          ms.auto_update = 0
          ms.data = ICC.get(:Courses, :courses, args: {center: Persons.center})
          if ms.data._code == 'Error'
            ms.step = 10
            status_list(true, status: "Error: #{ms.data._msg}")
          elsif ms.data._msg
            status_list(false, list: ms.data._msg.collect { |c|
                               c._name.sub!(Persons.center.login_name + '_', '')
                               [c._course_id, c._name]
                             })
          else
            ms.step = 10
            ms.auto_update = 0
            ms.status = status_list(true, status: 'Nothing received')
          end
        when 2
          ms.auto_update = -1
          data._import_list.each { |id|
            course = ms.data._msg.find { |d| d._course_id == id }
            ms.status = status_list(true, status: "Checking CourseType for #{course._name}")
            sleep 2
            if !ctype = CourseTypes.find_by_name(course._ctype)
              ms.status = status_list(true, status: "Fetching CourseType #{course._ctype}")
              sleep 2
              begin
                ctype = get_ctype(course._ctype, ms)
              rescue StandardError => e
                ms.step = 10
                ms.auto_update = 0
                ms.status = status_list(true, status: "Error: #{e.inspect}")
                return
              end
            end
            course._ctype = ctype
            sleep 2
            begin
              %w(teacher responsible assistant).each { |p|
                person = course[p]
                if person.to_s.length == 0 || person.first == 0
                  course[p] = 0
                  next
                end
                dputs(3) { "Fetching person #{person} for #{p}" }
                course[p] = Persons.match_by_login_name(person) || get_person(person, ms)
              }
              course._students.each { |p|
                next if p.to_s.length == 0
                next if p.first == 0
                next if Persons.match_by_login_name(p)
                dputs(3) { "Fetching student #{p}" }
                get_person(p, ms)
              }
            rescue StandardError => e
              ms.step = 10
              ms.auto_update = 0
              ms.status = status_list(true, status: "Couldn't fetch person - #{e}")
              return
            end

            course = Courses.create(course)

            # Fetch exam-files
            course._students.each { |stud|
              ms.status = status_list(true, status: "Fetching exams for #{name}")
              dp "fetching exams"
              m = ICC.get(:Courses, :_get_exams, args: {center: Persons.center._login_name,
                                                        course: course.name,
                                                        student: stud})
              if m._code == 'OK'
                dp "ok"
                path = File.join(ConfigBase.exam_dir, course.name, stud)
                Zip::InputStream.open(StringIO.new(m._data)) do |zip_file|
                  while entry = zip_file.get_next_entry
                    File.write(File.join(path, entry.name), entry.get_input_stream.read)
                  end
                end
              else
                dp "false"
                ms.step = 10
                ms.auto_update = 0
                ms.status = status_list(true, status: "Error while fetching exams #{m._msg}")
                return
              end
            }

            # Fetch grades
            m = ICC.get(:Courses, :grades_get, args: {course: course.name,
                                                      center: Persons.center._login_name})
            if m._code == 'OK'
              m._msg.each { |g|
                student = Persons.find_by_login_name(g._student)
                if !student
                  dputs(0) { "Got grade #{g} with unexisting student" }
                else
                  grade = Grades.match_by_course_person(course, student)
                  if grade
                    dputs(3) { "Updating for #{g}" }
                    grade.means = g._means
                    grade.remark = g._remark
                    grade.random = g._random
                  else
                    dputs(3) { "Making new grade with #{g}" }
                    g.delete('grade_id')
                    g._course = course
                    g._student = student
                    g._center = nil
                    grade = Grades.create(g)
                  end
                  dputs(3) { "Grade is now #{grade}" }
                end
              }
            else
              ms.step = 10
              ms.status = status_list(true, status: "Error while fetching grades #{m._msg}")
              return
            end

            log_msg :AdminServer, "Created course #{course}"
          }
          ms.auto_update = 0
          ms.step = 10
          status_list(true, status: 'Everything downloaded')
        when 10
          ms.step = -1
          reply(:window_hide)
      end
    }

    ms.make_step(session, data)
  end

end