class SelfCash < View
  def layout
    set_data_class :Persons
    @update = true
    @cache_payments = {}
    @order = 20
    
    gui_hboxg do
      show_int_ro :credit_due
      show_list_single :payments, :width => 400
    end
  end
  
  def rpc_update( session, client = nil )
    person = session.owner
    reply( 'empty', %w( payments ) ) +
    reply( 'update', { :credit_due => person.credit_due } ) +
    reply( 'update', { :payments => list_payments( session ) } )
  end
  
  def list_payments( session, force = false )
    person = session.owner
    if not @cache_payments[person.person_id] or force
      @cache_payments[person.person_id] = 
      Entities.LogActions.log_list( {:data_field=>"credit$",:data_class=>"Person"} ).select{|s|
        s[:msg] and s[:msg].split(":")[0].to_i == person.person_id.to_i
      }.collect{|e|
        worker, cash = e[:msg].split(":")
        client = Entities.Persons.find_by_person_id( e[:data_class_id] )
        if client
          "#{e[:date_stamp]}: #{cash} CFA to #{client.login_name}"
        else
          "#{e[:date_stamp]}: #{cash} CFA to id-#{e[:data_class_id]}"
        end
      }.reverse
    end
    @cache_payments[person.person_id]
  end
end
