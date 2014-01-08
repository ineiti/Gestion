# A ticket is opened for computers only

class Tickets < Entities
  def setup_data
    value_block :date
    value_date :opened
    value_date :closed
    value_list_drop :severity, "%w( critique grave moyen optionnel )"
    value_str_ro :created_by
    value_entity_person_empty :assigned, :drop, :full_name,
      lambda{|p| p.permissions.index("maintenance")}
    value_entity_computer_empty :computer, :drop, :name_service
    value_str :other
    
    value_block :detail
    value_text :todo
    value_text :verification
    value_text :work
  end
  
  def listp_opened( closed = false )
    search_all.select{|k|
      ( not k.closed ) ^ closed
    }.collect{|k|
      dputs( 4 ){ "k is #{k.inspect}" }
      comp = k.computer != 0 ? k.computer.name_service : "---"
      [k.ticket_id, "#{k.opened} - #{comp}" ] 
    }.sort{|a,b|
      a[1] <=> b[1]
    }.reverse
  end
  
  def listp_closed
    listp_opened( true )
  end
  
end

module TicketLayout
  def t_layout( method )
    set_data_class :Tickets
    @update = true
    @order = method == :opened ? 150 : 200
    
    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :ticket_list, method, :width => 150
        if method == :opened
          show_button :new_ticket, :delete
        else
          show_button :delete
        end
      end

      gui_vbox :nogroup do
        gui_hbox :nogroup do
          gui_vbox :nogroup do
            show_block :date
          end
          gui_vbox :nogroup do
            show_block :detail, :width => 150
          end
        end
        if method == :opened
          show_button :save_ticket
        else
          show_button :save
        end
      end
    end
  end
end