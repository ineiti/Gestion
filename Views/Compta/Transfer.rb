# To change this template, choose Tools | Templates
# and open the template in the editor.

class ComptaTransfer < View
  include PrintButton

  def layout
    @update = true
    @order = 10
    
    set_data_class :Persons

    gui_hbox  do
      gui_vbox :nogroup do
        show_entity_person_lazy :persons, :single, :callback => true
        show_button :do_transfer
      end
      gui_vbox :nogroup do
        show_table :report, :headings => [ :Date, :Desc, :Amount, :Sum ],
          :widths => [ 100, 300, 75, 75 ], :height => 400, :width => 570,
          :columns => [0, 0, :align_right, :align_right]
        show_print :print
      end
      
      window_print_status
    end
  end
  
  def rpc_button_do_transfer( session, data )
    dputs(3){"data is #{data.inspect} with owner #{session.owner.full_name}"}
    other = Persons.match_by_person_id( data["person_list"][0] )
    dputs(3){"Other is #{other.inspect}, id is #{data["person_list"].to_s.inspect}"}
    amount = ( other.account_due.total.to_f * 1000 ).to_i
    log_msg :comptatransfer, "#{session.owner.login_name} gets #{amount} from " +
      "#{other.login_name}"
    session.owner.get_all_due( other )
    
    vtlp_update_list( session ) + rpc_update( session )
  end
  
  def rpc_update( session )
    dputs(3){"rpc_update with #{session.inspect}"}
    reply( :empty, :persons ) +
      reply( :update, :persons => Persons.listp_account_due ) +
      reply_print( session )
  end
  
  def rpc_list_choice_persons( session, data )
    dp data
    reply( :empty, :report ) +
      reply( :update, :report => data._persons.report_list( :all ))
  end
  
  def rpc_button_print( session, data )
    send_printer_reply( session, :print, data,
      data._persons.report_pdf( :all ) )
  end
end
