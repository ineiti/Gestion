=begin
Shows the existing courses and the courses on the server, so that the
two can be synchronized.
=end

require 'rubygems'
require 'zip/zipfilesystem'; include Zip
require 'docsplit'

$create_pdfs = Thread.new{
  $new_pdfs = []
  loop{
    if $new_pdfs.length == 0
      Thread.stop
    end
    dputs 2, "Creating pdfs #{$new_pdfs.inspect}"
    `date >> /tmp/cp`
    pdfs = []
    n_pdfs = $new_pdfs.shift
    dir = File::dirname( n_pdfs.first )
    n_pdfs.sort.each{ |p|
      dputs 3, "Started thread for file #{p} in directory #{dir}"
      Docsplit.extract_pdf p, :output => dir
      dputs 5, "Finished docsplit"
      FileUtils::rm( p )
      dputs 5, "Finished rm"
      pdfs.push p.sub( /\.[^\.]*/, '.pdf' )
    }
    dputs 3, "Getting #{pdfs.inspect} out of #{dir}"
    all = "#{dir}/000-all.pdf"
    psn = "#{dir}/000-4pp.pdf"
    dputs 3, "Putting it all in one file"
    `pdftk #{pdfs.join( ' ' )} cat output #{all}`
    dputs 3, "Putting 4 pages of #{all} into #{psn}"
    `pdftops #{all} - | psnup -4 -f | ps2pdf -sPAPERSIZE=a4 - #{psn}.tmp`
    FileUtils::mv( "#{psn}.tmp", psn )
    dputs 2, "Finished"
  }
}

class CourseDiploma < View
  def layout
    set_data_class :Courses

    gui_hbox do
      gui_vbox :nogroup do
        show_list_single :courses, "Entities.Courses.list_courses", :callback => true
        show_button :do_grades
      end
      gui_vbox :nogroup do
        show_list :grade
        show_button :print
      end
      gui_window :missing_data do
        show_str :missing
        show_button :close
      end
    end
    
    @default_printer = @default_printer ? "-P #{@default_printer}" : ""
  end

  def rpc_list_choice( session, name, args )
    dputs 3, "rpc_list_choice with #{name} - #{args.inspect}"
    ret = reply('empty', ['grade'])
    case name
    when "courses"
      if args['courses'].length > 0
        course = Entities.Courses.find_by_course_id( args['courses'] )
        course and ret += reply( 'update', :grade => course.get_pdfs )
      end
    end
    return ret
  end

  def update_student_diploma( file, student, course )
    grade = Entities.Grades.find_by_course_person( course.course_id, student.login_name )
    if grade and grade.to_s != "NP"
      dputs 3, "New diploma for: #{course.course_id} - #{student.login_name} - #{grade.to_hash.inspect}"
      ZipFile.open(file){ |z|
        doc = z.read("content.xml")
        contents = ""
        dputs 5, "Contents is: #{course.contents.inspect}"
        course.contents.split("\n").each{|d|
          dputs 5, "One line is: #{d}"
          contents += d + "</text:p></text:list-item><text:list-item><text:p text:style-name='P2'>"
        }
        contents.sub!(/(.*)<\/text:p.*/, '\1')
        dputs 4, "Contents is: #{contents}"
        doc.gsub!( /_PROF_/, Entities.Persons.login_to_full( course.teacher ) )
        doc.gsub!( /_RESP_/, Entities.Persons.login_to_full( course.responsible ) )
        doc.gsub!( /_NOM_/, student.full_name )
        doc.gsub!( /_DUREE_/, course.duration )
        doc.gsub!( /_COURS_/, course.description )
        show_year = course.start.gsub(/.*\./, '' ) != course.end.gsub(/.*\./, '' )
        doc.gsub!( /_DU_/, course.date_fr( course.start, show_year ) )
        doc.gsub!( /_AU_/, course.date_fr( course.end ) )
        doc.gsub!( /_DESC_/, contents )
        doc.gsub!( /_SPECIAL_/, grade.remark || "" )
        doc.gsub!( /_MENTION_/, grade.mention )
        doc.gsub!( /_DATE_/, course.date_fr( course.sign ) )
        z.file.open("content.xml", "w"){ |f|
          f.write( doc )
        }
        z.commit
      }
    else
      FileUtils.rm( file )
    end
  end

  def rpc_button_do_grades( session, args )
    course_id = args['courses'][0]
    course = Courses.find_by_course_id(course_id)
    if not course or course.export_check
      if course
        return reply( "window_show", :missing_data ) +
        reply("update", :missing => course.export_check.join(":"))
      end
    else
      students = course.students
      digits = Math::log10( students.size + 1 ).ceil
      counter = 1
      dputs 2, "Diploma_dir is: #{course.diploma_dir}"
      if not File::directory? course.diploma_dir
        FileUtils::mkdir( course.diploma_dir )
      else
        FileUtils::rm( Dir.glob( course.diploma_dir + "/*" ) )
      end
      dputs 2, students.inspect
      students.each{ |s|
        student = Entities.Persons.find_by_login_name( s )
        if student
          dputs 2, student.login_name
          student_file = "#{course.diploma_dir}/#{counter.to_s.rjust(digits, '0')}-#{student.login_name}.odt"
          dputs 2, "Doing #{counter}: #{student.login_name}"
          FileUtils::cp( "#{Entities.Courses.diploma_dir}/base_gestion.odt", student_file )
          update_student_diploma( student_file, student, course )
        end
        counter += 1
      }
      FileUtils::rm( Dir.glob( course.diploma_dir + "/content.xml*" ) )
      $new_pdfs += [ Dir.glob( course.diploma_dir + "/*odt" ) ]
      if $new_pdfs.length > 0
        $create_pdfs.run
        rpc_list_choice( session, "courses", "courses" => course_id.to_s ) +
        reply( "auto_update", "-5" )
      end
    end
  end
  
  def rpc_update_with_values( session, args )
    course_id = args['courses'][0]
    ret = rpc_list_choice( session, "courses", "courses" => course_id.to_s )
    course = Entities.Courses.find_by_course_id( course_id )
    if course.get_pdfs.index( "000-4pp.pdf" )
      ret += reply( :auto_update, 0 )
    end
    return ret
  end

  def rpc_button_close( session, args )
    reply( "window_hide" )
  end
  
  def rpc_button_print( session, args )
    if args['grade'].length > 0
      course_id = args['courses'][0]
      course = Courses.find_by_course_id(course_id)
      dputs 2, "Printing #{args['grade'].inspect}"
      args['grade'].each{|g|
        `lpr #{@default_printer} #{course.diploma_dir}/#{g}`
      }
    end
  end
end
