class Accounts < Entities
  def setup_data
    @default_type = :SQLite
    
    value_str :name
    value_str :desc
    value_str :global_id
    value_str :total
    value_int :multiplier
    value_int :index
  end
end

class Account < Entity  
end
