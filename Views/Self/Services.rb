class SelfServices < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 30
    @functions_need = [:accounting]
    @visible = false
    
    gui_hbox do
      gui_vbox do
        gui_vbox :nogroup do
          show_int :copies_laser, :callback => :calc
          #show_int :heures_groupe_petit, :callback => :calc
          show_int :heures_groupe_grand, :callback => :calc
          show_int :CDs, :callback => :calc
        end
        gui_vbox :nogroup do
          show_str :autres_text, :callback => :calc
          show_int :autres_cfa, :callback => :calc
        end
        gui_vbox :nogroup do
          show_int :services_total
        end
        show_button :add_cash
      end
      show_int_ro :account_total_due
    end
  end
  
  def calc_total( values )
    dputs( 5 ){ "#{values.inspect}" }
    services_total = 0
    values.each{|k,v|
      dputs( 5 ){ "Searching for #{k}: #{v}" }
      case k
      when "copies_laser"
        services_total += v.to_i * 50
      when "heures_groupe_petit"
        services_total += v.to_f * 1000
      when "heures_groupe_grand"
        services_total += v.to_f * 2500
      when "CDs"
        services_total += v.to_i * 500
      when "autres_cfa"
        services_total += v.to_i
      end
    }
    services_total
  end
  
  def self.cash_msg( data )
    "{" + 
      data.collect{|k,v|
      v.to_f > 0 and "\"#{k}\"=>\"#{v}\""
    }.select{|m| m }.join(", ") + 
      "}"
  end
  
  # Adds the cash to the destination account, and puts the same amount into
  # the AfriCompta-framework
  def rpc_button_add_cash( session, data )
    dputs( 5 ){ "data is #{data.inspect}" }
    services_total = calc_total( data )
    dputs( 5 ){ "which amounts to #{services_total} CFA" }
    actor = session.owner
    data.delete( "services_total" )
    data.delete( "account_total_due" )
    actor.pay_service( services_total, SelfServices.cash_msg( data ) )
    reply( :empty_nonlists, nil ) + rpc_update( session )
  end
  
  def rpc_update( session )
    reply( :update, { :account_total_due => session.owner.account_total_due } )
  end
  
  def rpc_update_with_values( session, values = nil )
    dputs( 3 ){ "Got values: #{values.inspect}" }
    reply( :update, { :services_total => calc_total( values ) } )
  end
  
  def rpc_callback( session, name, data )
    rpc_update_with_values( session, data )
  end

end
