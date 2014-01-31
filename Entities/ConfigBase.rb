class ConfigBases < Entities
  @@functions = %w( network internet share 
    courses course_server course_client 
    inventory accounting quiz accounting_courses ).sort.to_sym
  @@functions_base = { :network => [ :internet, :share, :internet_only ],
    :courses => [ :course_server, :course_client, :accounting_courses ],
    :accounting => [ :accounting_courses ]
  }
  @@functions_conflict = [ [:course_server, :course_client] ]
  
  def add_config
    value_list_drop :isp, "%w( tigo prestabist airtel tawali ).sort"
  end
end

require 'Helpers/ConfigBase'
