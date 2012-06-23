# A classroom has:
# - different courses
# - inventory (desks, blackboard, computers)

class Classrooms < Entities
  def setup_data
    value_str :name
    value_int :max_students
    value_int :computers
  end
end
