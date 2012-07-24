class Movements < Entities
  def setup_data
		dputs 0, "init_movements"
    @default_type = :SQLiteAC
		@data_field_id = :id

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
