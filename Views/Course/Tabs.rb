class CourseTabs < View
  def layout
    @order = 20
    @update = true
    @functions_need = [:courses]

    gui_vbox :nogroup do
      show_str :search_txt
      show_list_single :courses, :flexheight => 1, :callback => true,
                       :width => 100
      show_button :search, :delete, :add, :import
    end

    gui_window :error do
      show_html "<h1>You're not allowed to do that</h1>"
      show_button :close
    end

    gui_window :not_all_elements do
      gui_vbox do
        gui_vbox :nogroup do
          show_str :ct_name
          show_int :ct_duration
          show_str :ct_desc
          show_text :ct_contents
          show_list_drop :ct_filename, 'CourseTypes.files'
        end
        gui_vbox :nogroup do
          show_str :new_room
          show_str :new_teacher
          show_str :new_center
        end
        show_button :add_missing, :close
      end
    end

    gui_window :add_course do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_entity_courseType_all :new_ctype, :drop, :name
          show_str :name_date
          show_entity_person :new_center_course, :drop, :full_name
          show_button :new_course, :close
        end
      end

      gui_window :win_confirm do
        show_html :confirm_delete_txt
        show_button :confirm_delete, :close
      end
    end
  end

  def rpc_update(session)
    hide = []
    if CourseTypes.data.size > 0
      hide.push :ct_name, :ct_duration, :ct_desc, :ct_contents, :ct_filename
    end
    if Rooms.data.size > 0
      hide.push :new_room
    end
    if (teachers = Persons.list_teachers).size > 0
      session.owner.permissions
      if (!session.owner.permissions.index('center')) ||
          teachers.select { |t| t =~ /^#{session.owner.login_name}_/ }.length > 0
        hide.push :new_teacher
      end
    end
    if Persons.find_by_permissions(:center)
      hide.push :new_center
    end
    if hide.size < 8
      (reply(:window_show, :not_all_elements) +
          hide.collect { |h| reply(:hide, h) }).flatten
    else
      rep = reply(:empty_nonlists, [:courses]) +
          reply(:update, :courses => Courses.list_courses(session))
      if not session.can_view('FlagAdminCourse')
        rep += reply(:hide, :delete) + reply(:hide, :add)
      end
      rep + reply(:hide, :import) + reply(:focus, :search_txt)
    end
  end

  def rpc_button_add_missing(session, args)
    args.to_sym!
    dputs(5) { args.inspect }
    if args._ct_name and args._ct_name.size > 0
      dputs(3) { 'Creating CourseType' }
      ct = CourseTypes.create(:name => args._ct_name, :duration => args._ct_duration,
                              :tests_str => 'Mean', :description => args._ct_desc,
                              :contents => args._ct_contents,
                              :diploma_type => ['simple'], :output => ['certificate'],
                              :page_format => [1], :file_diploma => args._ct_filename)
      dputs(1) { "New CourseType is #{ct.inspect}" }
    end
    if args._new_room and args._new_room.size > 0
      dputs(3) { 'Creating Room' }
      room = Rooms.create(:name => args._new_room)
      dputs(1) { "New room is #{room.inspect}" }
    end
    if args._new_teacher and args._new_teacher.size > 0
      dputs(3) { 'Creating Teacher' }
      teacher = Persons.create_person(args._new_teacher, session.owner)
      teacher.permissions = ['teacher']
      dputs(1) { "New teacher #{teacher.inspect}" }
    end
    if args._new_center and args._new_center.size > 0
      dputs(3) { 'Creating Center' }
      center = Persons.create(:complete_name => args._new_center)
      center.permissions = ['center']
      dputs(1) { "New center #{center.inspect}" }
    end
    reply(:window_hide) +
        rpc_update(session) +
        rpc_update_view(session) +
        reply(:pass_tabs, [:update_hook])
  end

  def rpc_button_delete(session, args)
    if not session.can_view('FlagAdminCourse')
      return reply(:window_show, :error)
    end
    dputs(3) { "session, data: #{[session, args.inspect].join(':')}" }
    course = Courses.match_by_course_id(args['courses'][0])
    dputs(3) { "Got #{course.name} - #{course.inspect}" }
    if course
      return reply(:window_show, :win_confirm) +
          reply(:update, :confirm_delete_txt => 'Do you really want to delete<br>' +
                           "course #{course.name}?")
    end
  end

  def rpc_button_confirm_delete(session, args)
    if not session.can_view('FlagAdminCourse')
      return reply(:window_show, :error)
    end
    dputs(3) { "session, data: #{[session, args.inspect].join(':')}" }
    course = Courses.match_by_course_id(args['courses'][0])
    dputs(3) { "Got #{course.name} - #{course.inspect}" }
    if course
      dputs(2) { "Deleting entry #{course}" }
      log_msg :Course, "User #{session.owner.login_name} deletes course #{course.name}"
      course.delete
      course.changed = true
    end

    reply(:empty_nonlists, [:courses]) +
        reply(:update, {:courses => Courses.list_courses(session)}) +
        reply(:child, reply(:empty_nonlists, [:students])) +
        reply(:window_hide)
  end

  def rpc_button_new_course(session, data)
    dputs(3) { "session: #{session} - data: #{data.inspect}" }

    course = Courses.create_ctype(data._new_ctype, data._name_date,
                                  session.owner)

    if session.owner.permissions.index('center')
      course.teacher = course.responsible = Persons.responsibles_raw.select { |p|
        p.login_name =~ /^#{session.owner.login_name}_/ }.first
    else
      course.teacher = Persons.find_by_permissions('teacher')
      course.responsible = Persons.find_by_permissions('director') ||
          course.teacher
    end

    log_msg :coursetabs, "Adding new course #{course.inspect}"

    reply(:window_hide) +
        rpc_update(session) +
        reply(:update, :courses => [course.course_id])
  end

  def rpc_button_add(session, data)
    reply(:window_show, :add_course) +
        reply(:update, :name_date => "#{Date.today.strftime('%y%m')}") +
        if ConfigBase.has_function?(:course_server) &&
            session._owner.has_role(:admin)
          reply(:show, :new_center_course) +
              reply(:empty_update, :new_center_course => Persons.centers)
        else
          reply(:hide, :new_center_course)
        end
  end

  def rpc_button_close(session, data)
    reply(:window_hide)
  end

  def rpc_button_search(session, data)
    txt = data._search_txt
    return unless txt.to_s.length >= 2
    courses = Courses.search_all_.select{|c|
      c.name + (c.ctype ? c.ctype.name : '') + c.students.to_s +
          [c.teacher, c.responsible].collect{|p| p && p.full_login}.join =~ /#{txt}/i
    }
    reply(:empty_nonlists, [:courses]) +
        reply(:update, :courses => Courses.sort_courses(courses))
  end

  def rpc_list_choice(session, name, args)
    dputs(3) { "New choice #{name} - #{args.inspect}" }

    reply(:pass_tabs, ['list_choice', name, args]) +
        reply(:fade_in, :parent_child)
  end

  def rpc_list_choice_sub(session, name, args)
    dputs(3) { "Sub-tab called with #{name}" }
  end

  def rpc_update_view(session, args = nil)
    super(session, args) +
        reply(:fade_in, 'parent,windows') +
        reply(:focus, :search_txt)
  end
end
