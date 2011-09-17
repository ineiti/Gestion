# Represents the different rooms available in the facility

class Rooms < Entities
  def setup_data
    value_str :name
    value_int :size
    value_int :computers
    value_str :description
  end
end

class Room < Entity
end