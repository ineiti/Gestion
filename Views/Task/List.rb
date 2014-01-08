class TaskList < View
  
  def layout
    set_data_class :Tasks
    @update = true
    
    gui_hbox do
      gui_vbox :nogroup do
        show_list_drop :year, "View.TaskList.list_years"
        show_list_drop :month, "1.upto(12).to_a"
        show_list_drop :person, "Entities.Workers.list_full_name"
        show_list_drop :client, "Entities.Clients.list_name"
        show_button :list
      end
      gui_vbox :nogroup do
        show_text :tasks_done
        show_text :summary
      end
    end
  end
  
  def list_years
    to = from = Time.now.year
    Entities.Tasks.list_date{|d|
      year = d.sub( /.*\./, '' )
      dputs( 5 ){ "date is #{d}, year is #{year}" }
      from = [ from, year ].min
      to = [ to, year ].max
    }
    dputs( 5 ){ "from #{from} to #{to}" }
    from.upto( to ).to_a
  end
  
  def rpc_button_list( session, data )
    dputs( 3 ){ data.inspect }
    worker = Entities.Workers.find_full_name( data["person"][0] )
    dputs( 3 ){ worker.inspect }
    client = Entities.Clients.match_by_name( data["client"][0] )
    dputs( 3 ){ client.inspect }
    list = Tasks.list_task_month( worker, data["year"][0], data["month"][0], client)
    dputs( 3 ){ list.inspect }
    tasks = ""
    hours = 0.0
    list.sort{|a,b| a[:date] <=> b[:date] }.each{|l|
      duration = l[:duration_hours] 
      tasks +=  "#{l[:date]} - #{duration} hour#{ duration.to_f < 2 ? '' : 's'}\n" +
      "#{l[:work]}\n"
      hours += l[:duration_hours].to_f
    }
    price = worker.function[0] == "assistant" ? client.price_assistant : client.price_expert
    summary = "#{data['month']} #{hours} #{( hours * price.to_i ).to_i}"
    reply( "update", { :tasks_done => tasks, :summary => summary } )
  end
  
end
