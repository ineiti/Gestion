=begin
Shows the existing courses and the courses on the server, so that the
two can be synchronized.
=end

#require 'rubygems'
require 'zip/zipfilesystem'; include Zip
require 'docsplit'

class CourseDiploma < View
  def layout
    set_data_class :Courses
    @order = 30
    @thread = nil

    gui_hbox do
      gui_vbox :nogroup do
        show_list :diplomas
        show_button :do_diplomas, :print
      end
      gui_window :missing_data do
        show_html :missing
        show_button :close
      end
      gui_window :printing do
        show_html :msg_print
        show_button :close
      end
    end
    
    @default_printer = $config[:default_printer] ? "-P #{$config[:default_printer]}" : nil
  end

  def rpc_list_choice( session, name, args )
    dputs( 3 ){ "rpc_list_choice with #{name} - #{args.inspect}" }
    ret = reply('empty', ['diplomas'])
    case name
    when "courses"
      if args['courses'].length > 0
        course = Entities.Courses.find_by_course_id( args['courses'].to_a[0] )
        course and ret += reply( 'update', :diplomas => course.get_pdfs )
      end
    end
    return ret
  end

  def update_student_diploma( file, student, course )
    grade = Entities.Grades.find_by_course_person( course.course_id, student.login_name )
    if grade and grade.to_s != "NP"
      dputs( 3 ){ "New diploma for: #{course.course_id} - #{student.login_name} - #{grade.to_hash.inspect}" }
      ZipFile.open(file){ |z|
        doc = z.read("content.xml")
        ddputs( 5 ){ "Contents is: #{course.contents.inspect}" }
        desc_p = /-DESC1-(.*)-DESC2-/.match( doc )[1]
				ddputs( 3 ){ "desc_p is #{desc_p}" }
        doc.gsub!( /-DESC1-.*-DESC2-/,
					course.contents.split("\n").join( desc_p ))
        doc.gsub!( /-PROF-/, Entities.Persons.login_to_full( course.teacher.join ) )
        doc.gsub!( /-RESP-/, Entities.Persons.login_to_full( course.responsible.join ) )
        doc.gsub!( /-NOM-/, student.full_name )
        doc.gsub!( /-DUREE-/, course.duration )
        doc.gsub!( /-COURS-/, course.description )
        show_year = course.start.gsub(/.*\./, '' ) != course.end.gsub(/.*\./, '' )
        doc.gsub!( /-DU-/, course.date_fr( course.start, show_year ) )
        doc.gsub!( /-AU-/, course.date_fr( course.end ) )
        doc.gsub!( /-SPECIAL-/, grade.remark || "" )
        doc.gsub!( /-MENTION-/, grade.mention )
        doc.gsub!( /-DATE-/, course.date_fr( course.sign ) )
        z.file.open("content.xml", "w"){ |f|
          f.write( doc )
        }
        z.commit
      }
    else
      FileUtils.rm( file )
    end
  end

  def make_pdfs( old, list )
    FileUtils::rm( old )
    if @thread
      dputs( 2 ){ "Thread is here, killing" }
      begin
        @thread.kill
        @thread.join
      rescue Exception => e  
        dputs( 0 ){ "Error while killing: #{e.message}" }
        dputs( 0 ){ "#{e.inspect}" }
        dputs( 0 ){ "#{e.to_s}" }
        puts e.backtrace
      end
    end
    dputs( 2 ){ "Starting new thread" }
    @thread = Thread.new{
      begin
				dputs( 2 ){ "Creating pdfs #{list.inspect}" }
				`date >> /tmp/cp`
				pdfs = []
				dir = File::dirname( list.first )
				list.sort.each{ |p|
					dputs( 3 ){ "Started thread for file #{p} in directory #{dir}" }
					Docsplit.extract_pdf p, :output => dir
					ddputs( 5 ){ "Finished docsplit" }
					FileUtils::rm( p )
					ddputs( 5 ){ "Finished rm" }
					pdfs.push p.sub( /\.[^\.]*$/, '.pdf' )
				}
				dputs( 3 ){ "Getting #{pdfs.inspect} out of #{dir}" }
				all = "#{dir}/000-all.pdf"
				psn = "#{dir}/000-4pp.pdf"
				dputs( 3 ){ "Putting it all in one file: pdftk #{pdfs.join( ' ' )} cat output #{all}" }
				`pdftk #{pdfs.join( ' ' )} cat output #{all}`
				dputs( 3 ){ "Putting 4 pages of #{all} into #{psn}" }
				`pdftops #{all} - | psnup -4 -f | ps2pdf -sPAPERSIZE=a4 - #{psn}.tmp`
				FileUtils::mv( "#{psn}.tmp", psn )
				dputs( 2 ){ "Finished" }
			rescue Exception => e  
				dputs( 0 ){ "Error in thread: #{e.message}" }
				dputs( 0 ){ "#{e.inspect}" }
				dputs( 0 ){ "#{e.to_s}" }
				puts e.backtrace
			end
		}
  end

  def rpc_button_do_diplomas( session, args )
    course_id = args['courses'][0]
    course = Courses.find_by_course_id(course_id)
    if not course or course.export_check
      if course
        return reply( "window_show", :missing_data ) +
					reply("update", :missing => "The following fields are not filled in:<br>" + 
						course.export_check.join("<br>"))
      end
    else
      students = course.students
      digits = Math::log10( students.size + 1 ).ceil
      counter = 1
      dputs( 2 ){ "Diploma_dir is: #{course.diploma_dir}" }
      if not File::directory? course.diploma_dir
        FileUtils::mkdir( course.diploma_dir )
      else
        FileUtils::rm( Dir.glob( course.diploma_dir + "/*" ) )
      end
      dputs( 2 ){ students.inspect }
      students.each{ |s|
        student = Entities.Persons.find_by_login_name( s )
        if student
          dputs( 2 ){ student.login_name }
          student_file = "#{course.diploma_dir}/#{counter.to_s.rjust(digits, '0')}-#{student.login_name}.odt"
          dputs( 2 ){ "Doing #{counter}: #{student.login_name}" }
          FileUtils::cp( "#{Entities.Courses.diploma_dir}/#{course.ctype.filename.join}", 
            student_file )
          update_student_diploma( student_file, student, course )
        end
        counter += 1
      }
      make_pdfs( Dir.glob( course.diploma_dir + "/content.xml*" ), Dir.glob( course.diploma_dir + "/*odt" ) )

      rpc_list_choice( session, "courses", "courses" => course_id.to_s ) +
				reply( "auto_update", "-5" )
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
    ret = nil
    if args['diplomas'].length > 0
      course_id = args['courses'][0]
      course = Courses.find_by_course_id(course_id)
      dputs( 2 ){ "Printing #{args['diplomas'].inspect}" }
      if @default_printer
        args['diplomas'].each{|g|
          `lpr #{@default_printer} #{course.diploma_dir}/#{g}`
        }
        ret = reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression de<ul><li>#{args['diplomas'].join('</li><li>')}</li></ul>en cours" )
      else
        ret = reply( :window_show, :printing ) +
					reply( :update, :msg_print => "Choisir le pdf:<ul>" +
						args['diplomas'].collect{|d|
						%x[ cp #{course.diploma_dir}/#{d} /tmp ] 
						"<li><a href=\"/tmp/#{d}\">#{d}</a></li>"
					}.join('') + "</ul>" )
      end
    end
    ret
  end
end
