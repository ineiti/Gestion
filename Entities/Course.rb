# A course has:
# - Beginning, End and days of week
# - Person.Students
# - Teacher and Assistant
# - Classroom

#require 'rubygems'
require 'zip/zipfilesystem'; include Zip
require 'docsplit'
require 'rqrcode_png'
require 'ftools'


class Courses < Entities
  attr_reader :dir_diplomas, :dir_exas, :dir_exas_share,
    :print_presence, :print_presence_small
  
  def setup_data

    value_block :name
    value_entity_courseType :ctype, :drop, :name
    value_str :name

    value_block :calendar
    value_date :start
    value_date :end
    value_date :sign
    value_int :duration
    value_list_drop :dow, "%w( lu-me-ve ma-je-sa lu-ve ma-sa )"
    value_list_drop :hours, "%w( 9-12 16-18 9-11 )"
    value_entity_room :classroom, :drop, :name
    # value_entity :classroom, :Rooms, :drop, :name

    value_block :students
    value_list :students

    value_block :teacher
    value_entity_person :teacher, :drop, :full_name,
      lambda{|p| p.permissions.index("teacher")}
    value_entity_person_empty :assistant, :drop, :full_name,
      lambda{|p| p.permissions.index("teacher")}
    value_entity_person :responsible, :drop, :full_name,
      lambda{|p| p.permissions.index("teacher") or
        p.permissions.index("center")
    }

    value_block :content
    value_str :description
    value_text :contents

    value_block :accounting
    value_int :salary_teacher
    value_int :salary_assistant
    value_int :students_start
    value_int :students_finish
    value_int :entry_total

    @dir_diplomas = get_config( "Diplomas", :Courses, :DiplomaDir )
    @dir_exas = get_config( "Exas", :Courses, :ExasDir )
    @dir_exas_share = get_config( "Exas/Share", :Courses, :ExasShare )

    [ @dir_exas, @dir_exas_share ].each{|d|
      File.exists? d or FileUtils.mkdir d
    }

    @thread = nil
    @print_presence = OpenPrint.new( "#{@dir_diplomas}/fiche_presence.ods" )
    @print_presence_small = OpenPrint.new( "#{@dir_diplomas}/fiche_presence_small.ods" )
  end
  
  def set_entry( id, field, value )
    case field.to_s
    when "name"
      value.gsub!(/[^a-zA-Z0-9_-]/, '_' )
    end
    super( id, field, value )
  end

  def list_courses(session=nil)
    ret = search_all
    if session != nil
      user = session.owner
      if not session.can_view( "FlagCourseGradeAll" )
        ret = ret.select{|d|
          ddputs(4){"teacher is #{d.teacher.inspect}, user is #{user.inspect}"}
          ( d.teacher and d.teacher.login_name == user.login_name ) or
            ( d.responsible and d.responsible.login_name == user.login_name )
        }
      end
    end
    ret.collect{ |d| [ d.course_id, d.name] }.sort{|a,b|
      a[1].gsub( /^[^0-9]*/, '' ) <=> b[1].gsub( /^[^0-9]*/, '' )
    }.reverse
  end
  
  def list_courses_for_person( person )
    ln = person.class == String ? person : person.login_name
    dputs( 3 ){ "Searching courses for person #{ln}" }
    ret = @data.values.select{|d|
      dputs( 3 ){ "Searching #{ln} in #{d.inspect} - #{d[:students].index(ln)}" }
      d[:students] and d[:students].index( ln )
    }
    dputs( 3 ){ "Found courses #{ret.inspect}" }
    ret.collect{ |d| [ d[:course_id ], d[:name] ] }.sort{|a,b|
      a[1].gsub( /^[^_]*_/, '' ) <=> b[1].gsub( /^[^_]*_/, '' )
    }.reverse    
  end

  def list_name_base
    return %w( base maint int net site )
  end
  
  def self.create_ctype( name, ctype )
    self.create( :name => "#{ctype.name}_#{name}" ).
      data_set_hash( ctype.to_hash.except(:name), true ).
      data_set( :ctype, ctype )
  end

  def self.from_date_fr( str )
    day, month, year = str.split(' ')
    day = day.gsub( /^0/, '' )
    if day == "1er"
      day = "1"
    end
    month = %w( janvier février mars avril mai juin juillet août
    septembre octobre novembre décembre ).index( month ) + 1
    "#{day.to_s.rjust(2, '0')}.#{month.to_s.rjust(2, '0')}.#{year.to_s.rjust(4, '2000')}"
  end

  def self.from_diploma( course_name, course_str )
    dputs( 1 ){ "Importing #{course_name}: #{course_str.gsub(/\n/,'*')}" }
    course = Entities.Courses.find_by_name( course_name ) or
      Entities.Courses.create( :name => course_name )

    lines = course_str.split( "\n" )
    template = lines.shift
    dputs( 1 ){ "Template is: #{template}" }
    dputs( 1 ){ "lines are: #{lines.inspect}" }
    case template
    when /base_gestion/ then
      course.teacher, course.responsible = lines.shift( 2 ).collect{|p|
        Entities.Persons.find_full_name( p )
      }
      if not course.teacher or not course.responsible then
        return nil
      end
      course.teacher, course.responsible = course.teacher.login_name, course.responsible.login_name
      course.duration, course.description = lines.shift( 2 )
      course.contents = ""
      while lines[0].size > 0
        course.contents += lines.shift
      end
      dputs( 1 ){ "Course contents: #{course.contents}" }
      lines.shift
      course.start, course.end, course.sign =
        lines.shift( 3 ).collect{|d| self.from_date_fr( d ) }
      lines.shift if lines[0].size == 0

      course.students = []
      while lines.size > 0
        grade, name = lines.shift.split( ' ', 2 )
        student = Entities.Persons.find_name_or_create( name )
        course.students.push( student.login_name )
        g = Entities.Grades.find_by_course_person( course.course_id, student.login_name )
        if g then
          g.mean, g.remark = Entities.Grades.grade_to_mean( grade ), lines.shift
        else
          Entities.Grades.create( :course_id => course.course_id, :person_id => student.person_id,
            :mean => Grades.grade_to_mean( grade ), :remark => lines.shift )
        end
      end
      dputs( 0 ){ "#{course.inspect}" }
    else
      import_old( lines )
    end
    course
  end
  
  def migration_1(c)
    name = c.data_get( :classroom, true )
    if name.class == Array
      name = name.join
    end
    dputs(4){"Converting for name #{name} with #{Rooms.search_all.inspect}"}
    r = Rooms.match_by_name( name )
    if ( not r ) and ( not r = Rooms.find_by_name( "" ) )
      r = nil
    end
    c.data_set( :classroom, r )
    dputs(4){"New room is #{c.classroom.inspect}"}
  end
  
  def migration_2_raw(c)
    %w( teacher assistant responsible ).each{|p|
      person = c[p.to_sym]
      dputs(4){"#{p} is before #{person.inspect}"}
      if p == "assistant" and person == ["none"]
        person = nil
      else
        begin
          person = Persons.find_by_login_name( person.join ).person_id
        rescue NoMethodError
          person = Persons.find_by_login_name("admin").person_id
        end
      end
      dputs(4){"#{p} is after #{person.inspect}"}
      c[p.to_sym] = person
    }
  end


end



class Course < Entity
  def setup_instance
    if not self.students.class == Array
      self.students = []
    end
  end

  def dir_diplomas
    @proxy.dir_diplomas + "/#{self.name}"
  end
  
  def dir_exas
    @proxy.dir_exas + "/#{self.name}"
  end
  
  def dir_exas_share
    @proxy.dir_exas_share + "/#{self.name}"
  end
  
  def list_students
    dputs( 3 ){ "Students for #{self.name} are: #{self.students.inspect}" }
    ret = []
    if self.students
      ret = self.students.collect{|s|
        if person = Entities.Persons.find_by_login_name( s )
          [ s, "#{person.full_name} - #{person.login_name}:#{person.password_plain}" ]
        end
      }
    end
    ret
  end

  def to_hash
    ret = super.clone
    ret.delete :students
    ret.merge :students => list_students
  end

  # Tests if we have everything necessary handy
  def export_check
    missing_data = []
    %w( start end sign duration teacher responsible description contents ).each{ |s|
      d = data_get s
      if not d or d.size == 0
        dputs( 1 ){ "Failed checking #{s}: #{d}" }
        missing_data.push s
      end
    }
    return missing_data.size == 0 ? nil : missing_data
  end

  def date_fr( d, show_year = true )
    day, month, year = d.split('.')
    day = day.gsub( /^0/, '' )
    if day == "1"
      day = "1er"
    end
    month = %w( janvier février mars avril mai juin juillet août septembre octobre novembre décembre )[month.to_i-1]
    if show_year
      [ day, month, year ].join( " " )
    else
      [ day, month ].join( " " )
    end
  end

  def export_diploma
    return if export_check

    d_start, d_end, d_sign = data_get( %w( start end sign ) )
    same_year = 0
    [ d_start, d_end, d_sign ].each{|d|
      year = d.gsub( /.*\./, '' )
      if same_year == 0
        same_year = year
      elsif same_year != year
        same_year = false
      end
    }
    txt = <<-END
base_gestion
#{Entities.Persons.find_by_login_name( data_get :teacher ).full_name}
#{Entities.Persons.find_by_login_name( data_get :responsible ).full_name}
#{data_get :duration}
#{data_get :description}
#{data_get :contents}

#{date_fr(d_start, same_year)}
#{date_fr(d_end, same_year)}
#{date_fr(d_sign)}
    END
    data_get( :students ).each{|s|
      grade = Entities.Grades.find_by_course_person( data_get( :course_id ), s )
      if grade
        txt += "#{grade} #{grade.student.full_name}\n" +
          "#{grade.remark}\n"
      end
    }
    dputs( 2 ){ "Text is: #{txt.gsub(/\n/, '*')}" }
    txt
  end

  def get_files
    if File::directory?( dir_diplomas )
      files = if ctype.output[0] == "certificate" 
        Dir::glob( "#{dir_diplomas}/*pdf" )
      else
        Dir::glob( "#{dir_diplomas}/*png" ) +
          Dir::glob( "#{dir_diplomas}/*zip" )
      end
      files.collect{|f| 
        File::basename( f ) 
      }.sort
    else
      []
    end
  end
  
  def dstart
    Date.strptime( start, '%d.%m.%Y' )
  end
  
  def dend
    Date.strptime( data_get( :end ), '%d.%m.%Y' )
  end
  
  def get_duration_adds
    return [0,0] if not start or not data_get( :end )
    dputs(4){"start is: #{start} - end is #{data_get(:end)} - dow is #{dow}"}
    days_per_week, adds = case dow.to_s
    when /lu-me-ve/, /ma-je-sa/
      [ 3,  [0, 2, 4] ]
    when /lu-ve/, /ma-sa/
      [ 5, [0, 1, 2, 3, 4] ]
    end
    weeks = ( ( dend - dstart ) / 7 ).ceil
    day = 0
    dow_adds = (0...weeks).collect{|w| adds.collect{|a|
        day += 1
        [ /#{1000 + day}/, a + w * 7 ]
      }
    }.flatten( 1 )
    dputs( 4 ){"dow_adds is now #{dow_adds.inspect}"}
    
    [ days_per_week * weeks, dow_adds ]
  end

  def print_presence( lp_cmd = nil )
    return false if not teacher or teacher.count == 0
    return false if not start or not data_get( :end ) or students.count == 0
    stud_nr = 1
    studs = students.collect{|s|
      stud = Entities.Persons.find_by_login_name( s )
      stud_str = stud_nr.to_s.rjust( 2, '0' )
      stud_nr += 1
      [ [ /Nom#{stud_str}/, stud.full_name ],
        [ /Login#{stud_str}/, stud.login_name ],
        [ /Passe#{stud_str}/, stud.password_plain ] ]
    }
    dputs( 3 ){ "Students are: #{studs.inspect}" }
    duration, dow_adds = get_duration_adds

    pp = if duration <= 25 and stud_nr <= 16
      @proxy.print_presence_small
    else
      @proxy.print_presence
    end
    lp_cmd and pp.lp_cmd = lp_cmd
    pp.print( studs.flatten(1) + dow_adds + [
        [ /Teacher/, teacher.full_name ],
        [ /Course_name/, name ],
        [ /2010-08-20/, dstart.to_s ],
        [ /20.08.10/, dstart.strftime("%d/%m/%y") ],
        [ /2010-10-20/, dend.to_s ],
        [ /20.10.10/, dend.strftime("%d/%m/%y") ],
        [ /123/, students.count ],
        [ /321/, duration ],
      ] )
  end
	
	
  def update_student_diploma( file, student )
    grade = Grades.find_by_course_person( course_id, student.login_name )
    dputs(0){"Course is #{name} - ctype is #{ctype.inspect}"}
    if grade and grade.to_s != "NP" and 
        ( ( ctype.files_collect[0] == "no" ) or
          ( exam_files( student ).count >= ctype.files_needed.to_i ) )
      dputs( 3 ){ "New diploma for: #{course_id} - #{student.login_name} - #{grade.to_hash.inspect}" }
      ZipFile.open(file){ |z|
        #presponsible = Persons.find_by_login_name( responsible.join )
        doc = z.read("content.xml")
        dputs( 5 ){ "Contents is: #{contents.inspect}" }
        if qrcode = /draw:image.*xlink:href="([^"]*).*QRcode.*\/draw:frame/.match( doc )
          dputs( 2 ){"QRcode-image is #{qrcode[1]}"}
          qr = RQRCode::QRCode.new( grade.get_url_label )
          png = qr.to_img
          png.resize(900, 900)
          z.file.open(qrcode[1], "w"){ |f|
            png.write( f )
          }
        end
        if desc_p_match = /-DESC1-(.*)-DESC2-/.match( doc )
          desc_p = desc_p_match[1]
          dputs( 3 ){ "desc_p is #{desc_p}" }
          doc.gsub!( /-DESC1-.*-DESC2-/,
            contents.split("\n").join( desc_p ))
        end
        doc.gsub!( /-PROF-/, teacher.full_name )
        role_diploma = "Responsable informatique"
        if responsible.role_diploma.to_s.length > 0
          role_diploma = responsible.role_diploma
        end
        doc.gsub!( /-RESP-ROLE-/, role_diploma )
        doc.gsub!( /-RESP-/, responsible.full_name )
        doc.gsub!( /-NOM-/, student.full_name )
        doc.gsub!( /-DUREE-/, duration.to_s )
        doc.gsub!( /-COURS-/, description )
        show_year = start.gsub(/.*\./, '' ) != self.end.gsub(/.*\./, '' )
        doc.gsub!( /-DU-/, date_fr( start, show_year ) )
        doc.gsub!( /-AU-/, date_fr( self.end ) )
        doc.gsub!( /-SPECIAL-/, grade.remark || "" )
        doc.gsub!( /-MENTION-/, grade.mention )
        doc.gsub!( /-DATE-/, date_fr( sign ) )
        doc.gsub!( /-COURS_TYPE-/, ctype.name )
        doc.gsub!( /-URL_LABEL-/, grade.get_url_label )
        z.file.open("content.xml", "w"){ |f|
          f.write( doc )
        }
        z.commit
      }
    else
      FileUtils.rm( file )
    end
  end

  def make_pdfs( old, list, format = :certificate )
    format = format.to_sym
    FileUtils.rm( old )
    if list.size == 0
      ddputs(4){"No files here, quitting"}
      return
    end
		
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
        dputs( 2 ){ "Creating #{output} #{list.inspect}" }
        `date >> /tmp/cp`
        outfiles = []
        dir = File::dirname( list.first )
        list.sort.each{ |p|
          dputs( 3 ){ "Started thread for file #{p} in directory #{dir}" }
          if format == :certificate
            Docsplit.extract_pdf p, :output => dir
          else
            Docsplit.extract_images p, :output => dir, 
            :density => 300, :format => png
          end
          dputs( 5 ){ "Finished docsplit" }
          FileUtils.rm( p )
          dputs( 5 ){ "Finished rm" }
          outfiles.push p.sub( /\.[^\.]*$/, format == :certificate ? '.pdf' : '.png' )
        }
        if format == :certificate
          dputs( 3 ){ "Getting #{outfiles.inspect} out of #{dir}" }
          all = "#{dir}/000-all.pdf"
          psn = "#{dir}/000-4pp.pdf"
          dputs( 3 ){ "Putting it all in one file: pdftk #{outfiles.join( ' ' )} cat output #{all}" }
          `pdftk #{outfiles.join( ' ' )} cat output #{all}`
          dputs( 3 ){ "Putting 4 pages of #{all} into #{psn}" }
          `pdftops #{all} - | psnup -4 -f | ps2pdf -sPAPERSIZE=a4 - #{psn}.tmp`
          FileUtils.mv( "#{psn}.tmp", psn )
          dputs( 2 ){ "Finished" }
        else
          ddputs(3){"Making a zip-file"}
          Zip::ZipFile.open("#{dir}/all.zip", Zip::ZipFile::CREATE){|z|
            Dir.glob( "#{dir}/*" ).each{|image|
              z.get_output_stream(image.sub(".*/", "")) { |f| 
                File.open(image){|fi|
                  f.write fi.read
                }
              }
            }
          }
        end
      rescue Exception => e  
        dputs( 0 ){ "Error in thread: #{e.message}" }
        dputs( 0 ){ "#{e.inspect}" }
        dputs( 0 ){ "#{e.to_s}" }
        puts e.backtrace
      end
    }
  end

  def prepare_diplomas( convert = true )
    digits = students.size.to_s.size
    counter = 1
    dputs( 2 ){ "dir_diplomas is: #{dir_diplomas}" }
    if not File::directory? dir_diplomas
      FileUtils.mkdir( dir_diplomas )
    else
      FileUtils.rm( Dir.glob( dir_diplomas + "/*" ) )
    end
    dputs( 2 ){ "Students: #{students.inspect}" }
    students.each{ |s|
      student = Persons.find_by_login_name( s )
      if student
        dputs( 2 ){ student.login_name }
        student_file = "#{dir_diplomas}/#{counter.to_s.rjust(digits, '0')}-#{student.login_name}.odt"
        dputs( 2 ){ "Doing #{counter}: #{student.login_name} - file: #{student_file}" }
        FileUtils.cp( "#{Courses.dir_diplomas}/#{ctype.filename.join}", 
          student_file )
        update_student_diploma( student_file, student )
      end
      counter += 1
    }
    if convert
      make_pdfs( Dir.glob( dir_diplomas + "/content.xml*" ), 
        Dir.glob( dir_diplomas + "/*odt" ), ctype.output[0] )
    end
  end
  
  # This prepares a zip-file as a skeleton for the center to copy the
  # files over.
  # The name of the zip-file is different from the directory-name, so that the
  # upload is less error-prone.
  def zip_create( session = nil )
    dir = "exa-#{name}"
    file = "#{name}.zip"
    tmp_file = "/tmp/#{file}"
      
    if students and students.size > 0
      File.exists?( tmp_file ) and File.unlink( tmp_file )
      Zip::ZipFile.open(tmp_file, Zip::ZipFile::CREATE){|z|
        z.mkdir dir
        students.each{|s|
          p = "#{dir}/#{s}"
          z.mkdir( p )
        }
      }
      return file
    end
    return nil
  end
  
  def zip_read( session = nil )
    dir_zip = "exa-#{name}"
    dir_exas = @proxy.dir_exas + "/#{name}"
    file = "/tmp/#{dir_zip}.zip"
    
    if File.exists?( file ) and students
      %x[ mv #{dir_exas} /tmp ]
      FileUtils.mkdir dir_exas

      ZipFile.open( file ){|z|
        students.each{|s|
          dir_zip_student = "#{dir_zip}/#{s}"
          dir_exas_student = "#{dir_exas}/#{s}"
          
          if ( files_student = z.dir.entries( dir_zip_student ) ).size > 0
            FileUtils.mkdir( dir_exas_student )
            files_student.each{|fs|
              z.extract( "#{dir_zip_student}/#{fs}", "#{dir_exas_student}/#{fs}")
            }
          end
        }
      }
      File.unlink file
    end
  end
  
  def exam_files( student )
    student_name = student.class == Person ? student.login_name : student
    ddputs(4){"Student-name is #{student_name.inspect}"}
    dir_exas = @proxy.dir_exas + "/#{name}"
    dir_student = "#{dir_exas}/#{student_name}"
    File.exists?( dir_student ) ?
      Dir.entries( dir_student ).select{|f| ! ( f =~ /^\./ ) } : []
  end
  
  def exas_prepare_files
    name.length == 0 and return
    if File.exists? dir_exas_share
      %x[ rm -rf #{dir_exas_share} ]
    end
      
    FileUtils.mkdir dir_exas_share
    students.each{|s|
      dir_s_exas = "#{dir_exas}/#{s}"
      if File.exists? dir_s_exas
        File.move dir_s_exas, dir_exas_share
      else
        FileUtils.mkdir "#{dir_exas_share}/#{s}"
      end
    }
    %x[ rm -rf #{dir_exas} ]
  end
  
  def exas_fetch_files
    name.length == 0 and return
    ddputs(3){"Starting to fetch files for #{name}"}
    if File.exists? dir_exas_share
      ddputs(3){"#{dir_exas_share} exists"}
      File.exists? dir_exas or FileUtils.mkdir dir_exas
      students.each{|s|
        ddputs(3){"Checking on student #{s}"}
        dir_student = "#{dir_exas_share}/#{s}"
        if File.exists? dir_student
          ddputs(3){"Moving student-dir of #{s}"}
          File.move dir_student, "#{dir_exas}"
        end
      }
    end
    %x[ rm -rf #{dir_exas_share} ]
  end
end