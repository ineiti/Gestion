class CashAdd < View
  def layout
    set_data_class :Persons
    @update = true
    @cache_payments = {}
    
    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          gui_vbox :nogroup do
            show_find :login_name
            show_find :person_id
          end
          gui_vbox :nogroup do
            show_int_ro :credit
            show_int :credit_add
          end
          show_button :add_cash
        end
        gui_vbox :nogroup do
          gui_vbox :nogroup do
            show_int_ro :credit_due
          end
#          gui_vbox :nogroup do
#            show_list_ro :services_active
#            show_entity :service, :Services, :drop, :name
#            show_button :add_service
#          end
        end
      end
      gui_hbox :nogroup do
        gui_fields :noflex do
          show_list_single :payments, :callback => true
        end
      end
    end
  end
  
  def rpc_find( session, field, data )
    dputs 5, "Got called with #{[session, field, data].inspect}"
    rep = @data_class.find_by( field, data )
    if rep
      rpc_update( session, rep )
    else
      rpc_update( session ) + reply( 'update', { "#{field}" => data } )
    end
  end
  
  # Adds the cash to the destination account, and puts the same amount into
  # the AfriCompta-framework
  def rpc_button_add_cash( session, data )
    if client = @data_class.add_cash( session, data ) 
      list_payments( session, true )
      return rpc_update( session, client )
    else
      rpc_update( session )
    end
  end
  
  def rpc_button_add_service( session, data )
    ret = []
    
    dputs 3, "#{data.inspect}"
    client = @data_class.find_by_person_id( data['person_id'].to_s )
    service = Entities.Services.find_by_name( data['service'][0].to_s )
    dputs 3, "#{client.inspect} wants to join #{service.inspect}"
    if client and service
      if not client.services_active.index( service.name )
        # Test if there is enough money
        if client.credit.to_i >= service.price.to_i
          dputs 3, "OK, rich enough, can join"
          Entities.Payments.create( { :desc => "Service:#{service.name}",
          :cash => service.price.to_i, :date => Time.now.to_i, :client => client.id } )
          client.set_entry( :credit, ( client.credit.to_i - service.price.to_i ).to_s,
          "Paid for service #{service.name}:#{service.price}" )
          ret = rpc_update( session, client )
        else
          dputs 3, "Nope, not rich enough"
        end
      end
    end
    Captive::check_services
    ret
  end
  
  def rpc_update( session, client = nil )
    person = session.Person
    rep = reply( 'empty', %w( payments ) ) +
    reply( 'update', { :credit_due => person.credit_due } )
    if client
      dputs 3, "client is: #{client.inspect}"
      sa = client.services_active
      data = client.data.merge( { :services_active => sa } )
      data.delete(:credit_due )
      rep += reply( 'update', data )
    end
    rep += reply( 'update', { :payments => list_payments( session ) } )
    rep
  end
  
  def list_payments( session, force = false )
    person = session.Person
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
  
  def rpc_list_choice( session, name, *args )
    client = nil
    dputs 5, args.inspect
    if args[0]['payments']
      client = Entities.Persons.find_by_login_name( args[0]['payments'][0].sub( /.* /, '') )
    end
    rpc_update( session, client )
  end
end
