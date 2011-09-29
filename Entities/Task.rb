class Tasks < Entities
  def setup_data
    value_str :date_name
    
    value_block :who
    value_str :client
    value_str :person
    
    value_block :work
    value_date :date
    value_list_drop :time, "22.times.collect{|t| sprintf( '%02i.%02i', 7 + ( t / 2 ).floor, 30 * ( t % 2 ) )}"
    value_int :duration_hours
    value_text :work
    
    value_block :other
    value_int :transport_length
    value_list_single :transport_type, "%w( moto voiture taxi )"
    value_int :cost
    value_str :cost_description
    value_int :gain
    value_str :gain_description
  end

  def data_to_time( d )
    dputs 3, d.inspect
    t = d[:date].split('.').values_at( 2, 1, 0 ) +
        d[:time].to_s.split('.')
    Time.utc( *t )
  end

  def listp_tasks
    @data.values.sort{|a,b|
        data_to_time(a) <=> data_to_time(b)
        }.reverse.collect{ |d|
      [ d[:task_id], data_to_time(d).strftime("%d.%m.%y") + " - " + d[:person].to_s]
      }
  end
  
  def list_task_month( worker, year, month, client )
    @data.values.select{|d|
      dputs 3, "Data is: #{d.inspect}"
      date = data_to_time( d )
      dputs 3, [ date.inspect, year, month, worker, d[:person] ].inspect
      date.year == year.to_i and 
        date.month == month.to_i and 
        worker == Entities.Workers.find_full_name( d[:person][0] ) and
        client.name == d[:client][0]
    }
  end
end

class Task < Entity
  
end
