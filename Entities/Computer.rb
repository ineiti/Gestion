# A classroom has:
# - different courses
# - inventory (desks, blackboard, computers)

class Computers < Entities
  def setup_data
    value_block :identity
    value_str :name_service
    value_entity_room :room, :drop, :name
    value_str :name_place
    
    value_block :performance
    value_str :brand
    value_int :RAM_MB
    value_int :HD_GB
    value_int :CPU_GHz

    value_block :ticket
    value_text :comment
  end
end

class Computer < Entity
end