class Users < Entities

  def setup_data
    @default_type = :SQLiteAC
		@data_field_id = :id
    
    value_str :name
    value_str :full
    value_str :pass
		# The last account_index that got transmitted
    value_int :account_index
		# The last movement_index that got transmitted
    value_int :movement_index
  end
end
