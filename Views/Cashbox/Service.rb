class CashboxService < View
  def layout
    set_data_class :Persons
    @update = true
    @order = 10
    
    gui_hbox do
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_int :copies_intern, :callback => :calc
          show_int :copies_extern, :callback => :calc
          #show_int :heures_groupe_petit, :callback => :calc
          show_int :heures_groupe_grand, :callback => :calc
          show_int :CDs, :callback => :calc
        end
        gui_vbox :nogroup do
          show_str :autres_text, :width => 200
          show_int :autres_cfa, :callback => :calc
        end
        gui_vbox :nogroup do
          show_int :services_total
        end
        show_date :date
        show_button :add_cash
      end
      gui_vbox :nogroup do
        gui_vbox :nogroup do
          show_int_ro :account_total_due
        end
        gui_vbox :nogroup do
          show_table :report, :headings => [ :Date, :Desc, :Amount, :Sum ],
            :widths => [ 100, 300, 75, 75 ], :height => 400, 
            :columns => [0, 0, :align_right, :align_right ]
        end
      end
    end
  end
  
  def calc_total( values )
    dputs( 5 ){ "#{values.inspect}" }
    services_total = 0
    values.each{|k,v|
      dputs( 5 ){ "Searching for #{k}: #{v}" }
      case k
      when "copies_intern"
        services_total += v.to_i * 50
      when "copies_extern"
        services_total += v.to_i * 100
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
  
  def cash_msg( data )
    "{" + 
      %w( copies_intern copies_extern heures_groupe_grand CDs autres_text ).select{|c| 
      data[c].to_s.length > 0
    }.collect{|k|
      "\"#{k}\"=>\"#{data[k]}\""
    }.join(", ") +
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
    actor.pay_service( services_total, cash_msg( data ),
      data._date )
    reply( :empty ) + rpc_update( session )
  end
  
  def rpc_update( session )
    dputs(3){"Fetching total"}
    ret = reply( :update, :account_total_due => session.owner.account_total_due )
    dputs(3){"Updating time"}
    ret += reply( :update, :date => Date.today.strftime("%d.%m.%Y"))
    dputs(3){"Getting report_list"}
    ret += reply( :update, :report => session.owner.report_list( :all ) )
    dputs(3){"Done"}
    ret
  end
  
  def rpc_update_with_values( session, values = nil )
    dputs( 3 ){ "Got values: #{values.inspect}" }
    reply( :update, :services_total => calc_total( values ) )
  end
  
  def rpc_callback( session, name, data )
    rpc_update_with_values( session, data )
  end

end

