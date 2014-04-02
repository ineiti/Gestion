# Allow for courses to be paid
# This module attributes the courses to the accounts. Normally this
# should happen automatically, but for old installations, this editor
# is necessary.

class ComptaCourse < View
  def layout
    @order = 50
    @update = true
    @functions_need = [:accounting_courses]
    @visible = false
    
    gui_hboxg do
      gui_vbox :nogroup do
        show_entity_course_lazy :courses, :single, :name,
          :flexheight => 1, :callback => true, :width => 100
      end
      gui_vbox do
        show_str :account_path, :width => 300
        show_button :new_account_path, :save
      end
      gui_window :win_new_account do
        gui_vbox :nogroup do
          show_list_single :new_account, :width => 500, :height => 300
          show_button :assign_new_account, :add_archives, :close
        end
      end
    end
    
  end
  
  def rpc_button_new_account_path( session, data )
    acc = []
    AccountRoot.actual.get_tree{|a|
      acc.push [ a.global_id, a.path ]
    }
    reply( :empty_only, :new_account ) +
      reply( :update, { :new_account => acc.sort{|a,b| a[1] <=> b[1] } }) +
      reply( :window_show, :win_new_account )
  end
  
  def rpc_button_save( session, data )
    dputs(4){"save with #{data.inspect} - #{data._courses} - #{data._account_path}"}
    reply( :empty, :new_account_path ) +
      if course = data._courses
      if ap = data._account_path and
          acc = Accounts.find_by_path(ap)
        dputs(3){"New account at #{ap} is #{acc.inspect} - #{acc.path}"}
        course.entries = acc
        reply( :update, :account_path => acc.path )
      elsif course.entries
        reply( :update, :account_path => course.entries.path )
      else
        []
      end
    else
      []
    end
  end
  
  def rpc_button_add_archives( session, data )
    
  end
  
  def rpc_button_assign_new_account( session, data )
    if gid = data._new_account[0] and
        acc = Accounts.find_by_global_id( gid )
      rpc_button_save( session, data.merge( "account_path" => acc.path ) )
    else
      []
    end +
      reply( :window_hide )
  end

  def rpc_button_close( session, data )
    reply( :window_hide )
  end
  
  def rpc_list_choice( session, name, data )
    dputs(4){"name is #{name} - data is #{data.inspect}"}
    if course = data._courses
      dputs(3){"Course is #{course.inspect}"}
      reply( :empty, [:account_path] ) +
        if course.entries and course.entries != []
        reply( :update, :account_path => course.entries.path )
      else
        []
      end
    end
  end
  
  def rpc_update( session )
    reply( :empty, :courses ) +
      reply( :update, :courses => Courses.list_courses(session))
  end
end
