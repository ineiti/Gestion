class Workers < Entities
  def setup_data
    value_block :person
    value_int :person_id
    value_str :login_name
    
    value_block :work
    value_list_drop :function, "%w( assistant expert )"
    value_date :start
    value_date :end
  end
  
  def list_full_name
    @data.values.collect{|d|
      p = Entities.Persons.find_by_person_id( d[:person_id] )
      String( p.first_name ) + " " + String( p.family_name )
    }
  end
  
  def find_full_name( name )
    person = @data.values.select{|d|
      p = Entities.Persons.find_by_person_id( d[:person_id] )
      n = String( p.first_name ) + " " + String( p.family_name )
      dputs( 3 ){ "#{d[:person_id].inspect} - #{name} - #{n} - #{name == n} - #{name == n}" }
      name == n
    }.first
    Entities.Workers.find_by_person_id( person[:person_id] )
  end
end
