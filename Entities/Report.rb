class ReportAccounts < Entities
  def setup_data
    value_entity_account :root, :drop
    value_entity_account :account, :drop
    value_int :level
  end
end


class Reports < Entities
  def setup_data
    value_str :name
    value_list_entity_reportAccounts :accounts
  end
end

class Report < Entity
  def print_list( start, stop )
    dp Entities.Reports.inspect
  end
  
  def print( start = Date.today, stop = Date.today + 365 )
    
  end
  
  def listp_accounts
    accounts.collect{|a|
      [ a.id, "#{a.level}: #{a.account.path}" ]
    }
  end
end