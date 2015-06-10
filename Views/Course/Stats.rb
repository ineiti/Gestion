class CourseStats < View
  def layout
    set_data_class :Courses
    @update = true
    @order = 100
    @functions_need = [:accounting]

    #@visible = false

    gui_vboxg do
      gui_hboxg :nogroup do
        gui_vbox :nogroup do
          show_block :accounting
        end
        gui_vboxg :nogroup do
          show_text :contacts, :flexheight => 1
        end
      end
      show_block :account
      show_arg :entries, :width => 500
      show_button :save, :create_account
    end
  end

  def rpc_button_save(session, data)
    if course = Courses.match_by_course_id(data._courses.first)
      dputs(3) { "Found course #{course.name} with data #{data.inspect}" }
      data.delete('students')
      course.data_set_hash(data)
    end
  end

  def rpc_button_create_account(session, data)
    if course = Courses.match_by_course_id(data._courses.first)
      course.create_account
      rpc_update_view(session) +
          rpc_list_choice(session, 'courses', data)
    end
  end

  def rpc_list_choice(session, name, args)
    dputs(3) { "rpc_list_choice with #{name} - #{args.inspect}" }
    if name == 'courses' and args['courses'].length > 0
      course_id = args['courses'][0]
      dputs(3) { "replying for course_id #{course_id}" }
      course = Courses.match_by_course_id(course_id)
      list = course.students.collect { |s| Persons.match_by_login_name(s) }.compact.
          collect { |s| [s.phone.to_s, s.email.to_s] }.transpose
      if list.length > 0
        phones = list[0].select { |l| l.to_s.length > 0 }.
            collect { |l| l.split('/').join("\n") }.join("\n")
        emails = list[1].select { |l| l.to_s.length > 0 && !(l[1] =~ /@ndjair.net/) }.
            join("\n")
      else
        phones = emails = ''
      end
      reply(:empty_nonlists) +
          reply(:update, :entries => [0]) +
          update_form_data(course) +
          reply_visible(course.entries.class != Account, :create_account) +
          reply(:update, :contacts => "Phones:\n#{phones}\n" +
                           "Emails:\n#{emails}")
    end
  end

  def rpc_update_view(session)
    super(session) +
        reply(:empty_nonlists, :entries) +
        reply(:update, :entries =>
                         [[0, 'None']].concat(AccountRoot.actual.listp_path))
  end

  def rpc_update(session)
    reply(:update, :entries => [0])
  end
end
