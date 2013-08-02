=begin
Shows the existing courses and the courses on the server, so that the
two can be synchronized.
=end


class CourseDiploma < View
  include PrintButton
  
  def layout
    set_data_class :Courses
    @order = 30
    @thread = nil
    @update = true

    gui_hbox do
      gui_vbox :nogroup do
        show_table :diplomas_t, :headings => [:Name, :Grade, :State],
          :widths => [200, 50, 100], :height => 500
      end
      gui_vbox :nogroup do
        gui_fields do
          show_info :status
          show_button :do_diplomas, :abort
        end
        show_print :print
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
  end
  
  def rpc_show( session )
    super( session ) +
      reply( :hide, [ :abort, :status ] )
  end
  
  def rpc_update( session )
    super( session ) +
      reply_print( session )
  end

  def rpc_list_choice( session, name, args )
    args.to_sym!
    dputs( 3 ){ "rpc_list_choice with #{name.inspect} - #{args.inspect}" }
    ret = []
    case name.to_s
    when "courses"
      ret = reply( :empty, :diplomas_t1 )
      if args._courses.length > 0
        if course = Entities.Courses.match_by_course_id( args._courses.to_a[0] )
          course.update_state
          ret += rpc_update_with_values( session, args )
        end
      end
    end
    return ret
  end

  def rpc_button_do_diplomas( session, args )
    course_id = args['courses'][0]
    course = Courses.match_by_course_id(course_id)
    if not course or course.export_check
      if course
        return reply( :window_show, :missing_data ) +
          reply( :update, :missing => "The following fields are not filled in:<br>" + 
            course.export_check.join("<br>"))
      end
    else
      course.prepare_diplomas

      rpc_list_choice( session, :courses, :courses => [course_id.to_s] )
    end
  end
  
  def rpc_update_with_values( session, args )
    args.to_sym!
    ( course_id = args._courses[0] ) or return []
    #ret = rpc_list_choice( session, "courses", "courses" => course_id.to_s )
    ret = []
    ( course = Entities.Courses.match_by_course_id( course_id ) ) or return []

    overall_state = course.make_pdfs_state["0"]
    if overall_state == "done"
      ret += reply( :auto_update, 0 ) +
        reply( :hide, [:abort,:status] ) +
        reply( :unhide, :do_diplomas )
    else
      ret += reply( :auto_update, -5 ) +
        reply( :unhide, [:abort,:status] ) +
        reply( :hide, :do_diplomas ) +
        reply( :update, :status => overall_state )
    end
    
    states = if course.get_files.index{|f| f =~ /(000-4pp.pdf|zip)$/ }
      if $1 =~ /zip$/
        [["all.zip",["All files"]]]
      else
        [["000-4pp.pdf",["4 on 1 page"]], ["000-all.pdf",["All diplomas"]]]
      end
    else
      []
    end
    states += course.make_pdfs_state.keys.reject{|k| k == "0"}.
      collect{|s|
      st = course.make_pdfs_state[s]
      [s, [Persons.find_by_login_name(s).full_name, st[0], st[1]]]
    }.sort{|a,b|
      a[1][0] <=> b[1][0]
    }
    
    return ret + 
      reply_print( session ) +
      reply( :update, :diplomas_t => states )
  end

  def rpc_button_close( session, args )
    reply( :window_hide )
  end
  
  def rpc_button_print( session, args )
    ret = rpc_print( session, :print, args ) +
      reply( :window_hide )
    lp_cmd = cmd_printer( session, :print )
    if ( names = args['diplomas_t'] ).length > 0
      course_id = args['courses'][0]
      course = Courses.match_by_course_id(course_id)

      files = names.collect{|f|
        file = "#{course.dir_diplomas}/#{f}"
        if ! File.exists? file
          file = "#{course.get_diploma_filename(f, 'pdf')}"
          if ! File.exists? file
            file = "Not found"
          end
        end
        ddputs(3){"Filename is #{file}"}
        name = ( ( p = Persons.find_by_login_name( f ) ) and p.full_name ) ||
          {"all.zip"=>"All files", "000-4pp.pdf"=>"4 on 1 page",
          "000-all.pdf"=>"All diplomas"}[f] || "Unknown"
        [ name, file ]
      }
      dputs( 2 ){ "Printing #{files.inspect}" }
      if lp_cmd
        names = []
        files.each{|name, file|
          if File.exists? file
            `#{lp_cmd} #{file}`
            names.push name
          end
        }
        ret += reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Impression de<ul><li>" +
            "#{names.join('</li><li>')}</li></ul>en cours" )
      else
        ret += reply( :window_show, :printing ) +
          reply( :update, :msg_print => "Choisir le pdf:<ul>" +
            files.collect{|name,file|
            if File.exists? file
              %x[ cp #{file} /tmp ] 
              "<li><a href=\"/tmp/#{File.basename(file)}\">#{name}</a></li>"
            else
              "<li>#{name} - not found</li>"
            end
          }.join('') + "</ul>" )
      end
    end
    ret
  end
  
  def rpc_button_abort( session, args )
    course_id = args['courses'][0]
    course = Entities.Courses.match_by_course_id( course_id )
    course.abort_pdfs
    reply( :unhide, :do_diplomas ) +
      reply( :hide, :abort ) +
      reply( :auto_update, 0 )
  end
end
