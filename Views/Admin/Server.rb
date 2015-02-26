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

  def check_availability
    if ConfigBase.server_url.to_s.length == 0
      [false, 'No server defined, aborting']
    else
      if Persons.center
        [true, 'Fetching CourseTypes from server']
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
    downloading, status = check_availability
    reply(:window_show, :win_import) +
        status_list(true, status: status) +
        (downloading ? reply(:callback_button, :download_list) : reply(:update))
  end

  def rpc_button_download_list(session, data)
    res = ICC.get(:CourseTypes, :list)
    if res._code == 'Error'
      status_list(true, status: "Error: #{res._msg}")
    else
      status_list(false, list: res._msg)
    end
  end

  def rpc_button_download_old(session, data)
    if (cts_names = data._import_list).length > 0
      status_list(true, status: "Downloading #{cts_names.length} CourseTypes").concat(
          reply(:callback_button, :fetch_list))
    else
      log_msg :CourseType, 'Nothing to download'
      reply(:window_hide)
    end
  end

  def rpc_button_fetch_list(session, data)
    cts_names = data._import_list
    cts = ICC.get(:CourseTypes, :fetch,
                  args: {course_type_names: cts_names})
    if cts._code == 'Error'
      return status_list(true, status: "Error: #{cts._msg}")
    end

    log_msg :CourseType, "Downloaded #{cts_names}"
    cts._msg.each { |ct|
      if ct_exist = CourseTypes.match_by_name(ct._name)
        log_msg :CourseType, "Updating CourseType #{ct._name}"
        ct_exist.data_set_hash(ct)
      else
        log_msg :CourseType, "Creating CourseType #{ct._name}"
        ct_new = CourseTypes.create(ct)
      end
      [ct._file_diploma, ct._file_exam].compact.each { |f|
        file = f.first
        if file.length > 0
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
    }
    status_list(true, status: "Downloaded #{cts_names.length} CourseTypes")
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
      case step
        when 0
          ms.auto_update = -1
          downloading, status = check_availability
          ms.step = (downloading ? 1 : 10)
          reply(:window_show, :win_import) +
              status_list(true, status: status)
        when 1
          ms.auto_update = 0
          ms.data = ICC.get(:Courses, :courses, args: {center: Persons.center})
          if ms.data._code == 'Error'
            ms.step = 10
            status_list(true, status: "Error: #{ms.data._msg}")
          else
            status_list(false, list: ms.data._msg.collect { |c| [c._course_id, c._name] })
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
                dputs(3) { "Fetching person #{person}" }
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
              ms.status = status_list(true, status: "Couldn't fetch person - #{e}")
              return
            end

            log_msg :AdminServer, "Created course #{Courses.create(course)}"
          }
          ms.auto_update = 0
          ms.step = 10
          status_list(true, status: 'Everything downloaded')
        when 10
          reply(:window_hide)
      end
    }

    ms.make_step(session, data)
  end

end