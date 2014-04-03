# To change this template, choose Tools | Templates
# and open the template in the editor.

class ComptaTransfer < View
  include VTListPane
  def layout
    @update = true
    @order = 10
    
    set_data_class :Persons

    gui_hbox  do
      gui_vbox :nogroup do
        vtlp_list :person_list, :account_due, :maxheight => 250
        show_button :empty
      end
      gui_vbox :nogroup do
        show_int_ro :account_cash
      end
    end
  end
  
  def rpc_button_empty( session, data )
    dputs(3){"data is #{data.inspect} with owner #{session.owner.full_name}"}
    other = Persons.match_by_person_id( data["person_list"][0] )
    dputs(3){"Other is #{other.inspect}, id is #{data["person_list"].to_s.inspect}"}
    amount = ( other.account_due.total.to_f * 1000 ).to_i
    log_msg :comptatransfer, "#{session.owner.login_name} gets #{amount} from " +
      "#{other.login_name}"
    session.owner.get_cash( other, amount )
    
    vtlp_update_list( session ) + rpc_update( session )
  end
  
  def rpc_update( session )
    dputs(3){"rpc_update with #{session.inspect}"}
    reply( :update, :account_cash => session.owner.account_total_due )
  end
end
