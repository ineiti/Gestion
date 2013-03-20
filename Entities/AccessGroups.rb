# Defines groups for access to the internet

class AccessGroups < Entities
  def setup_data
    value_str :name
    value_list_single :members
    value_list_drop :action, "%w( allow allow_else_block block )"
    value_int :priority
    value_int :limit_day_mo
    value_list_single :access_times, "[]"
  end
  
  def listp_name
    search_all.sort{|a,b|
      b.priority.to_i <=> a.priority.to_i
    }.collect{|ag|
      [ag.accessgroup_id, "#{ag.priority.rjust(2,'0')}:#{ag.name}"]
    }
  end
end