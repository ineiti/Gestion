class Services < Entities
  def setup_data
    value_str :name
    value_str :group
    value_int :price
    value_int :duration
  end
end

class Service < Entity
end