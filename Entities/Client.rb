class Clients < Entities
  def setup_data
    value_block :name
    value_str :name

    value_block :address
    value_str :addr1
    value_str :addr2
    value_str :country
    
    value_block :prices
    value_int :price_assistant
    value_int :price_expert
    
    value_block :contact
    value_str :email
    value_str :phone
  end
end

class Client < Entity
  
end