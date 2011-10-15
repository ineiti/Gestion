=begin
Shows the existing courses and the courses on the server, so that the
two can be synchronized.
=end

require 'rubygems'
require 'zip/zipfilesystem'; include Zip

require 'docsplit'

$create_pdfs = Thread.new{
  loop{
    Thread.stop
    dputs 0, "Creating pdfs #{$new_pdfs.inspect}"
    `date >> /tmp/cp`
    pdfs = []
    dir = File::dirname( $new_pdfs.first )
    $new_pdfs.each{ |p|
      dputs 0, "Started thread for file #{p} in directory #{dir}"
      Docsplit.extract_pdf p, :output => dir
      dputs 0, "Finished docsplit"
      FileUtils::rm( p )
      dputs 0, "Finished rm"
      pdfs.push p.sub( /\.[^\.]*/, '.pdf' )
    }
    dputs 0, "Getting #{pdfs.inspect} out of #{dir}"
    all = "#{dir}/000-all.pdf"
    psn = "#{dir}/000-4pp.pdf"
    #`pdftk #{pdfs} cat output #{all}`
    #`pdftops #{all} - | psnup -4 -f | ps2pdf - #{psn}` 
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
  end

  def rpc_list_choice( sid, name, args )
    dputs 3, "rpc_list_choice with #{name} - #{args.inspect}"
    ret = reply('empty', ['grade'])
    case name
    when "courses"
      if args['courses'].length > 0
        courseDir = @diplomaDir + "/" + Entities.Courses.find_by_course_id( args['courses'] ).name
        dputs 2, "Looking for directory #{courseDir}"
        if File::directory?( courseDir )
          ret += reply( 'update', :grade => Dir::entries( courseDir ).select{|s| s[0..0] != "." } )
        end
      end
    end
    return ret
  end

  def update_student_diploma( file, student, courseh )
    grade = Entities.Grades.find_by_course_person( courseh[:course_id], student.login_name )
    if grade
      dputs 3, "New diploma for: #{courseh[:course_id]} - #{student.login_name} - #{grade.to_hash.inspect}"
      ZipFile.open(file){ |z|
        doc = z.read("content.xml")
        contents = ""
        dputs 5, "Contents is: #{courseh[:contents].inspect}"
        courseh[:contents].split("\n").each{|d|
          dputs 5, "One line is: #{d}"
          contents += d + "</text:p></text:list-item><text:list-item><text:p text:style-name='P2'>"
        }
        contents.sub!(/(.*)<\/text:p.*/, '\1')
        dputs 4, "Contents is: #{contents}"
        doc.gsub!( /_PROF_/, courseh[:teacher][0] )
        doc.gsub!( /_RESP_/, courseh[:responsible][0] )
        doc.gsub!( /_NOM_/, student.full_name )
        doc.gsub!( /_DUREE_/, courseh[:duration] )
        doc.gsub!( /_COURS_/, courseh[:description] )
        doc.gsub!( /_DU_/, courseh[:start] )
        doc.gsub!( /_AU_/, courseh[:end] )
        doc.gsub!( /_DESC_/, contents )
        doc.gsub!( /_SPECIAL_/, grade.remark || "" )
        doc.gsub!( /_MENTION_/, grade.mention )
        doc.gsub!( /_DATE_/, courseh[:sign] )
        doc.gsub!( /_PROF_/, courseh[:teacher][0] )
        doc.gsub!( /_RESP_/, courseh[:responsible][0] )
        z.file.open("content.xml", "w"){ |f|
          f.write( doc )
        }
        z.commit
      }
    else
      FileUtils.rm( file )
    end
  end

  def rpc_button_do_grades( sid, args )
    course_id = args['courses'][0]
    course = @data_class.find_by_course_id(course_id)
    if not course or course.export_check
      if course
        return reply( "window_show", :missing_data ) +
        reply("update", :missing => course.export_check.join(":"))
      end
    else
      courseh = course.to_hash
      dputs 2, courseh.inspect
      students = courseh[:students]
      digits = Math::log10( students.size + 1 ).ceil
      counter = 1
      courseDir = @diplomaDir + "/" + courseh[:name]
      if not File::directory? courseDir
        FileUtils::mkdir( courseDir )
      else
        FileUtils::rm( Dir.glob( courseDir + "/*" ) )
      end
      dputs 2, students.inspect
      students.each{ |s|
        student = Entities.Persons.find_by_login_name( s[0] )
        if student
          dputs 2, student.login_name
          studentFile = "#{courseDir}/#{counter.to_s.rjust(digits, '0')}-#{student.login_name}.odt"
          dputs 2, "Doing #{counter}: #{student.login_name}"
          FileUtils::cp( "#{@diplomaDir}/base_gestion.odt", studentFile )
          update_student_diploma( studentFile, student, courseh )
        end
        counter += 1
      }
      FileUtils::rm( Dir.glob( courseDir + "/content.xml*" ) )
      $new_pdfs = Dir.glob( courseDir + "/*odt" )
      $create_pdfs.run
      rpc_list_choice( sid, "courses", "courses" => course_id.to_s )
    end
  end

  def rpc_button_close( sid, args )
    reply( "window_hide" )
  end
  
  def rpc_button_print( sid, args )
    if args['grade'].length > 0
      dputs 0, "Printing #{args['grade'].inspect}"
    end
  end
end