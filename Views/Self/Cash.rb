class SelfCash < View
  def layout
    set_data_class :Persons
    @update = true
    @cache_payments = {}
    @order = 20
    @functions_need = [:accounting]

    gui_vbox do
      gui_fields do
        show_int_ro :account_total_due, :width => 100
      end
      gui_fields do
        show_list_single :payments, :width => 500, :callback => true,
          :nopreselect => true
      end
      gui_fields do
        show_button :update
      end
    end
  end

  def rpc_update( session, client = nil )
    person = session.owner
    reply( 'empty', %w( payments ) ) +
      reply( 'update', { :account_total_due => person.account_total_due } ) +
      reply( 'update', { :payments => list_payments( session, true ) } )
  end

  def list_payments( session, force = false )
    dputs(3){"list_payments #{session.inspect}"}
    person = session.owner
    pid = person.person_id
    if not @cache_payments[pid] or force
      @cache_payments[pid] = if ad = person.account_due
        dputs(3){"account_due is here"}
        ad.movements.collect{|m|
          dputs(4){"Collecting #{m.inspect}"}
          "#{m.date} :: #{( m.value * 1000 ).floor.to_s.rjust(6,'_')} " + 
              ":: #{m.global_id}"
        }
      else
        ""
      end
    end
    dputs(3){"Found movements #{@cache_payments[pid].inspect}"}
    @cache_payments[pid]
  end

  def rpc_list_choice( session, name, args )
    if desc = args['payments']
      desc = desc[0]
      dputs( 2 ){ "New choice #{name} - #{args.inspect}" }
      if desc =~ /.*Gestion: internet_credit/
        login = desc.sub(/.*internet_credit pour -([^:]*).*/, '\1')
    
        reply( :parent, 
          reply( :init_values, [ :PersonTabs, { :search => login, :persons => [] } ] ) +
            reply( :switch_tab, :PersonTabs ) ) +
          reply( :switch_tab, :PersonModify )
      end
      #reply( :parent, reply( :update, :search => login) )
      #reply( :parent, View.PersonTabs.rpc_callback_search( session, 
      #  "search" => login ) )
    end
  end
  
  def rpc_button_update( session, data)
    rpc_update( session )
  end

end
