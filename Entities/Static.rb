class Statics < Entities
  def setup_data
    value_str :view_name
    value_str :data_str
  end

  def get( name )
    find_by_view_name( name ) or
    create( :view_name => name, :data_str => "" )
  end
end
