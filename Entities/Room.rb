# Represents the different rooms available in the facility

class Rooms < Entities
  def setup_data
    value_block :all
    value_str :name
    value_int :size
    value_str :ip_net
    value_int :computers
    value_str :description
  end
end