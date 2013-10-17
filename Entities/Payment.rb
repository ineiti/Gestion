class Payments < Entities
  def setup_data
    value_str :desc
    value_int :cash
    value_date :date
    # value_entity :client, :Person
  end
end
