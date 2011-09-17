=begin
Internet - an interface for the internet-part of Markas-al-Nour.
=end

module Captive
  def self.check_services
    groups_all = Entities.Services.search_all.collect{|s| s[:group] }
    Entities.Persons.search_all.each{|p|
      dputs 4, "For #{p.login_name}"
      groups_add = p.services_active.collect{|s| s[:group] }
      groups_del = groups_all.select{|g| groups_add.index(g) }
      if groups_add.size > 0
        dputs 3, "Adding groups #{groups_del.inspect}"
      end
      if groups_del.size > 0
        dputs 3, "Deleting groups #{groups_del.inspect}"
      end
    }
  end
end