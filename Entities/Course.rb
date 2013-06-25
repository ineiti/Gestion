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
require 'net/http'


class Courses < Entities
  attr_reader :dir_diplomas, :dir_exas, :dir_exas_share,
    :print_presence, :print_presence_small
  
  def setup_data

    value_block :name
    value_entity_courseType_ro :ctype, :drop, :name
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
    value_entity_person_lazy :teacher, :drop, :full_name
    #lambda{|p| p.permissions.index("teacher")}
    value_entity_person_empty_lazy :assistant, :drop, :full_name
    #lambda{|p| p.permissions.index("teacher")}
    value_entity_person_lazy :responsible, :drop, :full_name
    #lambda{|p| p.permissions.index("teacher")}
    
    value_block :center
    value_entity_person_empty :center, :drop, :full_name,
      lambda{|p| p.permissions.index("center")}

    value_block :content
    value_str :description
    value_text :contents

    value_block :accounting
    value_int :salary_teacher
    value_int :salary_assistant
    value_int :students_start
    value_int :students_finish
    value_int :entry_total

    @dir_diplomas ||= "Diplomas"
    @dir_exas ||= "Exas"
    @dir_exas_share ||= "Exas/Share"

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
          dputs(4){"teacher is #{d.teacher.inspect}, user is #{user.inspect}"}
          ( d.teacher and d.teacher.login_name == user.login_name ) or
            ( d.responsible and d.responsible.login_name == user.login_name ) or
            ( ( d.name =~ /^#{session.owner.login_name}_/) and 
              session.owner.permissions.index("center") )
        }
      end
    end
    ret.collect{ |d| [ d.course_id, d.name] }.sort{|a,b|
      a[1].gsub( /.*([0-9]{4}.*)/, '\1' ) <=> b[1].gsub( /.*([0-9]{4}.*)/, '\1' )
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
  
  def self.create_ctype( ctype, date, creator = nil )
    needs_center = ( ConfigBase.has_function?( :course_server ) and
        ( creator and creator.has_permission?( :center ) ) )
    dputs(4){"needs_center is #{needs_center.inspect}"}

    # Prepare correct name
    name = if needs_center
      "#{creator.login_name}_#{ctype.name}_#{date}"
    else
      "#{ctype.name}_#{date}"
    end
    
    # Check for double names
    suffix = ""
    counter = 1
    while Courses.match_by_name( name + suffix )
      counter += 1
      suffix = "-#{counter}"
    end
    name += suffix
  
    course = self.create( :name => name ).
      data_set_hash( ctype.to_hash.except(:name), true ).
      data_set( :ctype, ctype )

    if needs_center
      ddputs(3){"Got center of #{creator.inspect}"}
      course.center = creator
    elsif creator
      ddputs(3){"Got responsible of #{creator.class}"}
      course.responsible = creator
    end
    
    return course
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
    course = Entities.Courses.match_by_name( course_name ) or
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
        g = Entities.Grades.match_by_course_person( course.course_id, student.login_name )
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
    if ( not r ) and ( not r = Rooms.match_by_name( "" ) )
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
          person = Persons.match_by_login_name( person.join ).person_id
        rescue NoMethodError
          person = Persons.match_by_login_name("admin").person_id
        end
      end
      dputs(4){"#{p} is after #{person.inspect}"}
      c[p.to_sym] = person
    }
  end
end



class Course < Entity
  attr_reader :sync_state, :make_pdfs_state
  attr :thread
  
  def setup_instance
    if not self.students.class == Array
      self.students = []
    end
    
    check_students_dir
    @make_pdfs_state = {"0" => 'idle'}
    @only_psnup = true
  end
  
  def check_dir
    [ dir_diplomas, dir_exas, dir_exas_share ].each{|d|
      (! File.exists? d ) and FileUtils.mkdir( d )
    }    
  end
  
  def check_students_dir
    check_dir
    students.each{|s|
      [ dir_exas, dir_exas_share ].each{|d|
        (! File.exists? "#{d}/#{s}") and FileUtils.mkdir("#{d}/#{s}")
      }
    }
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
        if person = Entities.Persons.match_by_login_name( s )
          [ s, "#{person.full_name} - #{person.login_name}:#{person.password_plain}" ]
        end
      }
    end
    ret
  end

  def to_hash( unique_ids = false )
    ret = super( unique_ids ).clone
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
#{Entities.Persons.match_by_login_name( data_get :teacher ).full_name}
#{Entities.Persons.match_by_login_name( data_get :responsible ).full_name}
#{data_get :duration}
#{data_get :description}
#{data_get :contents}

#{date_fr(d_start, same_year)}
#{date_fr(d_end, same_year)}
#{date_fr(d_sign)}
    END
    data_get( :students ).each{|s|
      grade = Entities.Grades.match_by_course_person( data_get( :course_id ), s )
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
      stud = Entities.Persons.match_by_login_name( s )
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
    grade = Grades.match_by_course_person( course_id, student.login_name )
    dputs(0){"Course is #{name} - ctype is #{ctype.inspect} and grade is " +
        "#{grade.inspect} - #{grade.to_s}"}
    if grade and grade.to_s != "NP" and 
        ( ( ctype.diploma_type[0] == "simple" ) or
          ( exam_files( student ).count >= ctype.files_needed.to_i ) )
      @make_pdfs_state[student.login_name] = [ grade.mean, "queued" ]
      
      ddputs( 3 ){ "New diploma for: #{course_id} - #{student.login_name} - #{grade.to_hash.inspect}" }
      ZipFile.open(file){ |z|
        dputs(5){"Cours is #{self.inspect}"}
        doc = z.read("content.xml")
        dputs( 5 ){ "Contents is: #{contents.inspect}" }
        if qrcode = /draw:image.*xlink:href="([^"]*).*QRcode.*\/draw:frame/.match( doc )
          dputs( 2 ){"QRcode-image is #{qrcode[1]}"}
          qr = RQRCode::QRCode.new( grade.get_url_label )
          png = qr.to_img
          png.resample_nearest_neighbor!(900, 900)
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
        doc.gsub!( /-TEACHER-/, teacher.full_name )
        role_diploma = "Enseignant informatique"
        if teacher.role_diploma.to_s.length > 0
          role_diploma = teacher.role_diploma
        end
        doc.gsub!( /-TEACHER_ROLE-/, role_diploma )
        role_diploma = "Responsable informatique"
        if responsible.role_diploma.to_s.length > 0
          role_diploma = responsible.role_diploma
        end
        doc.gsub!( /-RESP_ROLE-/, role_diploma )
        doc.gsub!( /-RESP-/, responsible.full_name )
        doc.gsub!( /-NAME-/, student.full_name )
        doc.gsub!( /-DURATION-/, duration.to_s )
        doc.gsub!( /-COURSE-/, description )
        show_year = start.gsub(/.*\./, '' ) != self.end.gsub(/.*\./, '' )
        doc.gsub!( /-FROM-/, date_fr( start, show_year ) )
        doc.gsub!( /-TO-/, date_fr( self.end ) )
        doc.gsub!( /-SPECIAL-/, grade.remark || "" )
        doc.gsub!( /-MENTION-/, grade.mention )
        doc.gsub!( /-DATE-/, date_fr( sign ) )
        doc.gsub!( /-COURSE_TYPE-/, ctype.name )
        doc.gsub!( /-URL_LABEL-/, grade.get_url_label )
        c = center
        doc.gsub!( /-CENTER_NAME-/, c.full_name )
        doc.gsub!( /-CENTER_ADDRESS-/, c.address || "" )
        doc.gsub!( /-CENTER_PLACE-/, c.town || "" )
        doc.gsub!( /-CENTER_PHONE-/, c.phone || "" )
        doc.gsub!( /-CENTER_EMAIL-/, c.email || "" )

        z.file.open("content.xml", "w"){ |f|
          f.write( doc )
        }
        z.commit
      }
    else
      reason = if ( ( ctype.diploma_type[0] != "simple" ) and
            ( exam_files( student ).count < ctype.files_needed.to_i ) )
        "incomplete"
      else
        "not passed"
      end
      mean = if grade and grade.mean
        grade.mean
      else
        "-"
      end
      @make_pdfs_state[student.login_name] = [ mean, reason ]

      FileUtils.rm( file )
    end
  end

  def make_pdfs( convert )
    if @thread
      dputs( 2 ){ "Thread is here, killing" }
      begin
        abort_pdfs
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
        digits = students.size.to_s.size
        counter = 1
        dputs( 2 ){ "Preparing students: #{students.inspect}" }
        if ! @only_psnup
          students.each{ |s|
            student = Persons.match_by_login_name( s )
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
        end
        
        dputs( 2 ){ "Convert is #{convert.inspect}" }
        if convert
          old = Dir.glob( dir_diplomas + "/content.xml*" )
          list = Dir.glob( dir_diplomas + "/*odt" )
          format = ctype.output[0].to_sym
          
          ddputs(4){"old is #{old.inspect}"}
          ddputs(4){"list is #{list.inspect}"}

          FileUtils.rm( old )
          if list.size == 0
            dputs(2){"No files here, quitting"}
            @make_pdfs_state["0"] = "done"
            @thread.kill
          end
          dputs( 2 ){ "Creating -#{output}-#{list.inspect}-" }
          `date >> /tmp/cp`
          %x[ ls -l #{dir_diplomas} >> /tmp/cp ]
          outfiles = []
          dir = File::dirname( list.first )
          @only_psnup and list = []
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
            @make_pdfs_state[p.sub(/.*-/, '').sub(/\.odt/, '')][1] = "done"
          }
          if format == :certificate
            dputs( 3 ){ "Getting #{outfiles.inspect} out of #{dir}" }
            all = "#{dir}/000-all.pdf"
            psn = "#{dir}/000-4pp.pdf"
            dputs( 3 ){ "Putting it all in one file: pdftk #{outfiles.join( ' ' )} cat output #{all}" }
            `pdftk #{outfiles.join( ' ' )} cat output #{all}`
            dputs( 3 ){ "Putting 4 pages of #{all} into #{psn}" }
            pf = ctype.data_get(:page_format, true)[0]
            format = ['', '-f', '-l', '-r'][pf]
            ddputs(3){"Page-format is #{format}"}
            `pdftops #{all} - | psnup -4 #{format} | ps2pdf -sPAPERSIZE=a4 - #{psn}.tmp`
            FileUtils.mv( "#{psn}.tmp", psn )
            dputs( 2 ){ "Finished" }
          else
            dputs(3){"Making a zip-file"}
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
        end
      rescue Exception => e  
        dputs( 0 ){ "Error in thread: #{e.message}" }
        dputs( 0 ){ "#{e.inspect}" }
        dputs( 0 ){ "#{e.to_s}" }
        puts e.backtrace
      end
      @make_pdfs_state["0"] = "done"
    }
  end

  def prepare_diplomas( convert = true )
    dputs( 2 ){ "dir_diplomas is: #{dir_diplomas}" }
    if not File::directory? dir_diplomas
      FileUtils.mkdir( dir_diplomas )
    else
      if ! @only_psnup
        FileUtils.rm( Dir.glob( dir_diplomas + "/*" ) )
      end
    end
    @make_pdfs_state = {"0" => 'working'}
    #@make_pdfs_state = {}
    make_pdfs( convert )
  end
  
  # This prepares a zip-file as a skeleton for the center to copy the
  # files over.
  # The name of the zip-file is different from the directory-name, so that the
  # upload is less error-prone.
  def zip_create( for_server = false, include_files = true )
    pre = for_server ? center.login_name + '_' : ''
    dir = "exa-#{pre}#{name}"
    file = "#{pre}#{name}.zip"
    tmp_file = "/tmp/#{file}"
      
    if students and students.size > 0
      File.exists?( tmp_file ) and File.unlink( tmp_file )
      Zip::ZipFile.open(tmp_file, Zip::ZipFile::CREATE){|z|
        z.mkdir dir
        students.each{|s|
          p = "#{dir}/#{pre}#{s}"
          z.mkdir( p )
          if include_files
            dputs(3){"Searching in #{dir_exas}/#{s}"}
            Dir.glob( "#{dir_exas}/#{s}/*" ).each{|exa_f|
              dputs(3){"Adding file #{exa_f}"}
              z.file.open( "#{p}/#{exa_f.sub(/.*\//, '')}", "w"){|f|
                f.write File.open(exa_f){|ef| ef.read }
              }
            }
          end
        }
      }
      return file
    end
    return nil
  end
  
  def zip_read( f = nil )
    name.length == 0 and return
    
    dir_zip = "exa-#{name.sub(/^#{center}_/, '')}"
    dir_exas = @proxy.dir_exas + "/#{name}"
    file = f || "/tmp/#{dir_zip}.zip"
    
    if File.exists?( file ) and students
      %x[ rm -rf /tmp/#{name} ]
      %x[ test -d #{dir_exas} && mv #{dir_exas} /tmp ]
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
    dputs(4){"Student-name is #{student_name.inspect}"}
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
    dputs(3){"Starting to fetch files for #{name}"}
    if File.exists? dir_exas_share
      dputs(3){"#{dir_exas_share} exists"}
      File.exists? dir_exas or FileUtils.mkdir dir_exas
      students.each{|s|
        dputs(3){"Checking on student #{s}"}
        dir_student = "#{dir_exas_share}/#{s}"
        if File.exists? dir_student
          dputs(3){"Moving student-dir of #{s}"}
          File.move dir_student, "#{dir_exas}"
        end
      }
    end
    %x[ rm -rf #{dir_exas_share} ]
  end
  
  def sync_send_post( field, data )
    path = URI.parse( "#{ctype.get_url}/" )
    post = { :field => field, :data => data }
    dputs(4){"Sending to #{path.inspect}: #{data.inspect}"}
    ret = Net::HTTP.post_form( path, post )
    dputs(4){"Return-value is #{ret.inspect}, body is #{ret.body}"}
    return ret.body
  end
  
  def sync_transfer( field, transfer, slow = false )
    ss = @sync_state
    block_size = 1024
    transfer_md5 = Digest::MD5.hexdigest( transfer )
    t_array = []
    while t_array.length * block_size < transfer.length
      start = (block_size * t_array.length)
      t_array.push transfer[start..(start+block_size -1)]
    end
    if t_array.length > 0
      pos = 0
      dputs(4){"Going to transfer: #{t_array.inspect}"}
      tid = Digest::MD5.hexdigest( rand.to_s )
      ret = sync_send_post( :start, { :field => field, :chunks => t_array.length,
          :md5 => transfer_md5, :tid => tid,
          :user => center.login_name, :pass => center.password_plain,
          :course => name }.to_json )
      return ret if ret =~ /^Error:/
      t_array.each{|t|
        @sync_state = "#{ss} #{( (pos+1) * 100 / t_array.length ).floor}%"
        dputs(3){@sync_state}
        ret = sync_send_post( tid, t )
        return ret if ret =~ /^Error:/
        slow and sleep 3
        pos += 1
      }
      return ret
    else
      dputs(2){"Nothing to transfer"}
      return nil
    end
  end
  
  def sync_do( slow = false )
    @sync_state = sync_s = "<li>Transferring course</li>"
    dputs(3){@sync_state}
    slow and sleep 3

    @sync_state = sync_s += "<li>Transferring responsibles: "
    users = [ teacher.login_name, responsible.login_name, center.login_name ]
    ret = sync_transfer( :users, users.collect{|s|
        Persons.match_by_login_name( s ) 
      }.to_json, slow )
    @sync_state += ret
    if ret =~ /^Error: /
      return false
    end
    @sync_state = sync_s += "OK</li>"

    if students.length > 0
      @sync_state = sync_s += "<li>Transferring users: "
      users = students + [ teacher.login_name, responsible.login_name ]
      ret = sync_transfer( :users, users.collect{|s|
          Persons.match_by_login_name( s ) 
        }.to_json, slow )
      @sync_state += ret
      if ret =~ /^Error: /
        return false
      end
      @sync_state = sync_s += "OK</li>"
    end

    @sync_state = sync_s += "<li>Transferring course: "
    myself = self.to_hash( true )
    myself._students = students
    ret = sync_transfer( :course, myself.to_json, slow )
    @sync_state += ret
    if ret =~ /^Error: /
      return false
    end
    @sync_state = sync_s += "OK</li>"

    if ( grades = Grades.search_by_course_id( course_id ) ).length > 0
      @sync_state = sync_s += "<li>Transferring grades: "
      ret = sync_transfer( :grades, grades.select{|g|
          g.course and g.person
        }.collect{|g| 
          dputs(4){"Found grade with #{g.course.inspect} and #{g.person.inspect}"}
          g.to_hash( true ).merge( :course => g.course.name, 
            :person => g.person.login_name )
        }.to_json, slow )
      @sync_state += ret
      if ret =~ /^Error: /
        return false
      end
      @sync_state = sync_s += "OK</li>"
    end

    if file = zip_create( true )
      @sync_state = sync_s += "<li>Transferring exams: "
      file = "/tmp/#{file}"
      dputs(3){"Exa-file is #{file}"}
      ret = sync_transfer( :exams, File.open(file){|f| f.read }, slow )
      @sync_state += ret
      if ret =~ /^Error: /
        return false
      end
      @sync_state = sync_s += "OK</li>"
    end

    @sync_state = sync_s += "It is finished!"
    dputs(3){@sync_state}
    return true
  end
  
  def sync_start
    if @thread
      dputs( 2 ){ "Thread is here, killing" }
      begin
        abort_pdfs
      rescue Exception => e  
        dputs( 0 ){ "Error while killing: #{e.message}" }
        dputs( 0 ){ "#{e.inspect}" }
        dputs( 0 ){ "#{e.to_s}" }
        puts e.backtrace
      end
    end
    dputs( 2 ){ "Starting new thread" }
    @sync_state = "Starting"
    @thread = Thread.new{
      begin
        sync_do
      rescue Exception => e  
        dputs( 0 ){ "Error in thread: #{e.message}" }
        dputs( 0 ){ "#{e.inspect}" }
        dputs( 0 ){ "#{e.to_s}" }
        puts e.backtrace
      end
    }
  end
  
  def get_unique
    name
  end
  
  def center
    ret = data_get( :center ) || Persons.find_by_permissions( :center )
    ddputs(3){"Center is #{ret.login_name}"}
    ret
  end
  
  def abort_pdfs
    if @thread
      ddputs(3){"Killing thread #{@thread}"}
      @thread.kill
      @thread.join
      ddputs(3){"Joined thread"}
    end    
  end
  
  def delete
    abort_pdfs
    
    [ dir_diplomas, dir_exas, dir_exas_share ].each{|d|
      FileUtils.remove_entry_secure( d, true )      
    }
    super
  end
end
