class Movements < Entities
  def setup_data
    @default_type = :SQLite

    value_str :src
    value_str :dst
    value_float :value
    value_str :desc
    value_str :date
    value_int :revision
    value_int :global_id
    value_int :index
  end
end

class Movement < Entity  
end
