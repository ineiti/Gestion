class Plugs < Entities
  def setup_data
    value_str :internal_id
    value_str :fixed_id
    value_str :center_name
    value_str :center_id
    value_str :center_city
    value_str :ip_local
    value_date :installation
    value_str :telephone
    value_list_drop :model, '%w(DreamPlug08 DreamPlug10 Smileplug Cubox-i1 Cubox-i4)'
    value_int :storage_size
  end
end