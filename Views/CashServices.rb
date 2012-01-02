class CashServices < View
  def layout
    set_data_class :Persons
    @update = true
    @auto_update = 1
    
    gui_hbox do
      gui_vbox do
        gui_vbox :nogroup do
          show_int :copies_laser
          show_int :heures_groupe_petit
          show_int :heures_groupe_grand
          show_int :CDs
        end
        gui_vbox :nogroup do
          show_str :autres_text
          show_int :autres_cfa
        end
        gui_vbox :nogroup do
          show_int :services_total
        end
        show_button :add_cash
      end
      show_int_ro :credit_due
    end
  end
  
  def calc_total( values )
    dputs 5, "#{values.inspect}"
    services_total = 0
    values.each{|k,v|
      dputs 5, "Searching for #{k}: #{v}"
      case k
        when "copies_laser"
        services_total += v.to_i * 50
        when "heures_groupe_petit"
        services_total += v.to_f * 1000
        when "heures_groupe_grand"
        services_total += v.to_f * 2000
        when "CDs"
        services_total += v.to_i * 500
        when "autres_cfa"
        services_total += v.to_i
      end
    }
    services_total
  end
  
  # Adds the cash to the destination account, and puts the same amount into
  # the AfriCompta-framework
  def rpc_button_add_cash( session, data )
    dputs 5, "data is #{data.inspect}"
    services_total = calc_total( data )
    dputs 5, "which amounts to #{services_total} CFA"
    actor = session.Person
    data.delete( "services_total" )
    data.delete( "credit_due" )
    actor.move_cash( services_total, data.inspect )
    reply( 'empty', nil ) + rpc_update( session )
  end
  
  def rpc_update( session )
    reply( 'update', { :credit_due => session.Person.credit_due } )
  end
  
  def rpc_update_with_values( session, values = nil )
    dputs 3, "Got values: #{values.inspect}"
    reply( 'update', { :services_total => calc_total( values ) } )
  end
  
end