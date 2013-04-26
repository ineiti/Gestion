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
          show_button :prepare_files, :fetch_files, :transfer_files
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
          show_button :save
        end
      end
      gui_window :transfer do
        show_html :txt
        show_upload :files
        show_button :close
      end
    end
  end

  def rpc_update( session )
    super( session ) +
      reply( "empty" ) +
      [ :prepare_files, :fetch_files, :transfer_files ].collect{|b|
      reply( :hide, b )
    }.flatten
  end

  def update_grade( d )
    ret = []
    c_id, p_name = d['courses'][0], d['students'][0]
    if p_name and c_id
      person = Persons.find_by_login_name( p_name )
      course = Courses.find_by_course_id( c_id )
      grade = Entities.Grades.find_by_course_person( c_id, p_name )
      if grade
        ret = reply( :update, grade.to_hash ) +
          to_means_true( course ){|i| 
          reply( :update, "mean#{i}" => grade.means[i-1])
        }.flatten
      else
        ret = reply( :empty )
      end
      ret += reply( :update, person.to_hash ) +
        reply( :update, :files_saved => course.exam_files( p_name ).count )
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
    ret = reply('empty')
    case name
    when "courses"
      course_id = args['courses'][0]
      course = Courses.find_by_course_id(course_id)
      if course
        dputs( 3 ){ "replying" }
        ret = reply("empty", [:students]) +
          reply("update", course.to_hash ) +
          reply("update", {:courses => [course_id]}) +
          reply("focus", :mean1 )
        if course.students.size > 0
          ret += reply("update", {:students => [course.students[0]]} ) +
            update_grade( {"courses" => [course.course_id],
              "students" => [course.students[0]]})
        end

        ret += to_means( course ){|s, i| 
          s ?  reply( :unhide, "mean#{i}" ) : reply( :hide, "mean#{i}")
        }.flatten

        ret += reply( course.ctype.files_collect[0] == "no" ? :hide : :unhide, 
          :files_saved)
        
        buttons = [ :prepare_files, :fetch_files, :transfer_files ]
        { :no => [0,0,0], :share => [1,1,0], :transfer => [0,0,1] }.fetch( 
          course.ctype.files_collect[0].to_sym, [0,0,0] ).each{|show|
          ret += reply( show == 1 ? :unhide : :hide, buttons.shift )
        }
        
        ddputs(4){"Course is #{course} - ret is #{ret.inspect}"}
      end
    when "students"
      ret += update_grade( args )
    end
    ret + reply( :focus, :mean1 )
  end

  def rpc_button_save( session, data )
    dputs( 3 ){ "Data is #{data.inspect}" }
    course = Courses.find_by_course_id( data['courses'][0])
    student = Entities.Persons.find_by_login_name( data['students'][0])
    if course and student
      Entities.Grades.save_data( {:course_id => course.course_id,
          :person_id => student.person_id,
          :means => to_means_true( course ){|i| data["mean#{i}"].to_i},
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

      reply( "empty", [:students] ) +
        update_grade( data ) +
        reply( 'update', {:students => course[:students]} ) +
        reply( 'update', {:students => [data['students'][0]] } ) +
        reply( 'focus', :mean1 )
    end
  end
  
  def rpc_button_transfer_files( session, data )
    ret = reply( :update, :txt => "no students" ) +
      reply( :hide, :upload )
    if course = Courses.find_by_course_id( data['courses'][0])
      if file = course.zip_create( session )
        @files.data_str.push file
        ret = reply( :update, :txt => "Download skeleton: " +
            "<a href='/tmp/#{file}'>#{file}</a>" ) +
          reply( :unhide, :upload )
      end
    end
    reply( :window_show, :transfer ) +
      ret
  end
  
  def rpc_button_close( session, data )
    if course = Courses.find_by_course_id( data['courses'][0])
      course.zip_read( session )
      reply( :window_hide )
    end
  end
end