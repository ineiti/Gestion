class SelfCash < View
  def layout
    set_data_class :Persons
    @update = true
    @cache_payments = {}
    @order = 20

    gui_vbox do
      gui_fields do
        show_int_ro :credit_due, :width => 100
      end
      gui_fields do
        show_list_single :payments, :width => 400, :callback => true
      end
    end
  end

  def rpc_update( session, client = nil )
    person = session.owner
    reply( 'empty', %w( payments ) ) +
      reply( 'update', { :credit_due => person.credit_due } ) +
      reply( 'update', { :payments => list_payments( session, true ) } )
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

  def rpc_list_choice( session, name, args )
    if args['payments']
      dputs( 2 ){ "New choice #{name} - #{args.inspect}" }
      login = args['payments'][0].gsub(/.* /, '')
    
      reply( :parent, 
        reply( :init_values, [ :PersonTabs, { :search => login, :persons => [] } ] ) +
          reply( :switch_tab, :PersonTabs ) ) +
        reply( :switch_tab, :PersonModify )
      #reply( :parent, reply( :update, :search => login) )
      #reply( :parent, View.PersonTabs.rpc_callback_search( session, 
      #  "search" => login ) )
    end
  end

end
