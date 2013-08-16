# Manages grades of a course
# - Add or change grades
# - Print out grades

class CourseGrade < View
  def layout
    set_data_class :Courses

    @update = true
    @order = 20
    # Not used - but don't dare deleting it - yet
    @files = Entities.Statics.get( :CourseGradeFiles )
    if @files.data_str.class != Array
      @files.data_str = []
    end

    gui_hbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_list_single :students, :width => 300, :callback => true
          show_str_ro :last_synched
          show_button :prepare_files, :fetch_files, :transfer_files, :sync_server
        end
        gui_vbox :nogroup do
          show_int :mean1
          show_int :mean2
          show_int :mean3
          show_int :mean4
          show_int :mean5
          show_int_ro :files_saved
          show_str :remark
          show_str :first_name, :width => 150
          show_str :family_name
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
      
      gui_window :single_file do
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

  def rpc_update( session )
    super( session ) +
      reply( :empty, [:students] ) +
      [ :prepare_files, :fetch_files, :transfer_files, 
      :last_synched, :sync_server, :upload, :files_saved ].collect{|b|
      reply( :hide, b )
    }.flatten
  end
  
  def update_files_saved( course, student )
    reply( :update, :files_saved => 
        "#{course.exam_files( student ).count}/#{course.ctype.files_needed}" )
  end

  def update_grade( d )
    ret = []
    c_id, p_name = d['courses'][0], d['students'][0]
    if p_name and c_id
      person = Persons.match_by_login_name( p_name )
      course = Courses.match_by_course_id( c_id )
      grade = Entities.Grades.match_by_course_person( c_id, p_name )
      if grade
        ret = update_form_data( grade ) +
          to_means_true( course ){|i| 
          reply( :update, "mean#{i}" => grade.means[i-1])
        }.flatten
      else
        ret = reply( :empty )
      end
      ret += update_form_data( person ) +
        update_files_saved( course, p_name )
    end
    ret
  end
  
  def to_means( course )
    (1..5).collect{|i|
      yield [ ( course and i <= course.ctype.tests.to_i ), i ]
    }
  end
  
  def to_means_true( course, &b )
    to_means( course ){ |s, i|
      s and b.call( i )
    }.select{|v| v }
  end

  def rpc_list_choice( session, name, args )
    dputs( 3 ){ "rpc_list_choice with #{name} - #{args.inspect}" }
    ret = reply( :empty )
    case name
    when "courses"
      course_id = args['courses'][0]
      course = Courses.match_by_course_id(course_id)
      if course
        dputs( 3 ){ "replying" }
        ret = rpc_update( session ) +
          #reply(:empty, [:students]) +
          update_form_data( course ) +
          reply(:update, {:courses => [course_id]}) +
          reply(:focus, :mean1 )
        if course.students.size > 0
          ret += reply(:update, {:students => [course.students[0]]} ) +
            update_grade( {"courses" => [course.course_id],
              "students" => [course.students[0]]})
        end

        ret += to_means( course ){|s, i| 
          s ? reply( :unhide, "mean#{i}" ) : reply( :hide, "mean#{i}")
        }.flatten

        dputs(3){"CType is #{course.ctype.inspect} - #{course.ctype.files_needed.inspect}"}
        buttons = []
        if (course.ctype.diploma_type[0] != "simple") and
            (course.ctype.files_needed.to_i > 0)
          dputs(3){"Putting buttons"}
        
          buttons.push :transfer_files, :upload, :files_saved
          if Shares.match_by_name( "CourseFiles" )
            buttons.push :prepare_files, :fetch_files
          end
        end
        if course.ctype.diploma_type[0] == "accredited" and
            ConfigBase.has_function?( :course_client )
          buttons.push :sync_server
        end
        buttons.each{|b|
          ret += reply( :unhide, b )
        }
        
        dputs(4){"Course is #{course} - ret is #{ret.inspect}"}
      end
    when "students"
      ret += update_grade( args )
    end
    ret + reply( :focus, :mean1 )
  end

  def rpc_button_save( session, data )
    dputs( 3 ){ "Data is #{data.inspect}" }
    course = Courses.match_by_course_id( data['courses'][0])
    student = Entities.Persons.match_by_login_name( data['students'][0])
    if course and student
      means = to_means_true( course ){|i| 
        if data.has_key?( "mean#{i}" ) and d = data["mean#{i}"]
          d.sub(/,/, '.').to_f 
        else
          0.0
        end
      }
      Entities.Grades.save_data( {:course => course,
          :student => student,
          :means => means,
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
      dputs( 2 ){ "Found student at #{saved}" }
      data['students'] = course[:students][( saved + 1 ) % course[:students].size]
      dputs( 2 ){ "Next student is #{data['students'].inspect}" }

      reply( :empty, :students ) +
        update_grade( data ) +
        reply( :update, :students => course[:students] ) +
        reply( :update, :students => [data['students'][0]] ) +
        reply( :focus, :mean1 )
    end
  end
  
  def rpc_button_transfer_files( session, data )
    ret = reply( :update, :txt => "no students" ) +
      reply( :hide, :upload )
    if course = Courses.match_by_course_id( data['courses'][0])
      if file = course.zip_create
        @files.data_str.push file
        ret = reply( :update, :txt => "Download skeleton: " +
            "<a target='other' href='/tmp/#{file}'>#{file}</a>" ) +
          reply( :unhide, :upload )
      end
    end
    reply( :window_show, :transfer ) +
      ret
  end
  
  def rpc_button_prepare_files( session, data )
    if course = Courses.match_by_course_id( data['courses'][0])
      course.exas_prepare_files
    end
    update_grade( data )
  end
  
  def rpc_button_fetch_files( session, data )
    if course = Courses.match_by_course_id( data['courses'][0])
      course.exas_fetch_files
    end
    update_grade( data )
  end
  
  def rpc_button_close( session, data )
    if course = Courses.match_by_course_id( data['courses'][0])
      course.zip_read
      reply( :window_hide ) +
        update_grade( data ) +
        reply( :auto_update, 0 )
    end
  end

  def rpc_update_with_values( session, data )
    ret = []
    if course = Courses.match_by_course_id( data['courses'][0])
      ret = reply( :update, :synching => "Sync-state:<ul>" + course.sync_state )
      if course.sync_state =~ /(finished|Error:)/
        ret += reply( :auto_update, 0 )
      end
    end
    ret
  end

  def rpc_button_sync_server( session, data )
    if course = Courses.match_by_course_id( data['courses'][0])
      course.sync_start

      reply( :window_show, :sync ) +
        reply( :auto_update, -5 ) +
        rpc_update_with_values( session, data )
    else
      reply( :window_show, :sync ) +
        reply( :update, :synching => "Please chose a course first")
    end
  end
  
  def rpc_button_upload( session, data, window_show = true )
    data.to_sym!
    course = Courses.match_by_course_id( data._courses[0])
    student = Entities.Persons.match_by_login_name( data._students[0])
    files_needed = course.ctype.files_needed.to_i
    exam_files = course.exam_files( student )
    dputs(3){"Exam-files = #{exam_files.inspect}"}
    ret = window_show ? reply( :window_show, :single_file ) : []
    ret + (1..5).collect{|i|
      show = :hide
      ret = []
      if i <= files_needed
        show = :unhide
        file_nb = exam_files.index{|f| f =~ /^#{i}-/ }
        file = file_nb ? exam_files[file_nb] : ""
        ret += reply( :update, "name_file_#{i}" =>
            "file ##{i}: #{file}" ) +
          reply( :update, "upload_file_#{i}" => "0" )
      end
      dputs(3){"Return is #{ret.inspect}"}
      ret +
        reply( show, "name_file_#{i}" ) +
        reply( show, "upload_file_#{i}" )
    }.flatten
  end
  
  def rpc_button( session, name, data )
    if name =~ /^upload_file_/
      number = name.sub( /.*_/, '' )
      
      data.to_sym!
      course = Courses.match_by_course_id( data._courses[0])
      student = data._students[0]
      dputs(4){"Course is #{course} - filename is #{data._filename} " +
          "student is #{student}" }
      if course and student and data._filename
        files_needed = course.ctype.files_needed.to_i
        close_window = files_needed == ( course.exam_files( student ).count + 1 )

        course.check_students_dir
        filename = UploadFiles.escape_chars( data._filename )
        src = "/tmp/#{filename}"
        dst = "#{Courses.dir_exas}/#{course.name}/#{student}"
        dputs(3){ "Moving #{src} to #{dst}" }
        FileUtils.rm Dir.glob( "#{dst}/#{number}-*" )
        FileUtils.mv src, "#{dst}/#{number}-#{filename}"

        ret = rpc_button_upload( session, data, false ) +
          update_files_saved( course, student )
        if close_window and ( files_needed == course.exam_files( student ).count )
          ret += reply( :window_hide )
        end
        dputs(3){"Return is #{ret.inspect}"}
        return ret
      end
    else
      return super( session, name, data )
    end
  end
end
