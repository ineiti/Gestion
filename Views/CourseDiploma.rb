=begin
Shows the existing courses and the courses on the server, so that the
two can be synchronized.
=end

require 'rubygems'
require 'zip/zipfilesystem'; include Zip
require 'docsplit'

class CourseDiploma < View
  def layout
    set_data_class :Courses

    gui_hbox do
      gui_vbox :nogroup do
        show_list_single :courses, "Entities.Courses.list_courses", :callback => true
        show_button :do_grades
      end
      gui_vbox :nogroup do
        show_list_single :grade
        show_button :print
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
          ret += reply( 'update', :grade => Dir::entries( courseDir ) )
        end
      end
    end
    return ret
  end

  def update_student_diploma( file, student )
    ZipFile.open(file){ |z|
      doc = z.read("content.xml")
      doc.gsub!( /_NOM_/, "#{student.full_name}" )
      z.file.open("content.xml", "w"){ |f|
        f.write( doc )
      }
    }
    Docsplit.extract_pdf file
  end

  def rpc_button_do_grades( sid, args )
    course_id = args['courses'][0]
    course = @data_class.find_by_course_id(course_id).to_hash
    students = course[:students]
    digits = Math::log10( students.size + 1 ).ceil
    counter = 1
    courseDir = @diplomaDir + "/" + course[:name]
    if not File::directory? courseDir
      FileUtils::mkdir( courseDir )
    else
      FileUtils::rm( Dir.glob( courseDir + "/*" ) )
    end
    dputs 2, students.inspect
    students.each{ |s|
      student = Entities.Persons.find_by_login_name( s[0] )
      studentFile = "#{courseDir}/#{counter.to_s.rjust(digits, '0')}-#{student.login_name}.odt"
      dputs 2, "Doing #{counter}: #{s[0]}"
      FileUtils::cp( "#{@diplomaDir}/base_gestion.odt", studentFile )
      update_student_diploma( studentFile, student )
      counter += 1
    }
    rpc_list_choice( sid, "courses", "courses" => course_id.to_s )
  end
end