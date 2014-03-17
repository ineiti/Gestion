# To change this template, choose Tools | Templates
# and open the template in the editor.

class SelfChat < View
  def layout
    @@box_length = 40
    @@disc = Entities.Statics.get( :SelfChat )
    @@disc.data_str.length < @@box_length and
      @@disc.data_str = Array.new(@@box_length, "")
    @order = 100
    @update = true
    @auto_update = 10
    @auto_update_send_values = false
    @functions_need = [:network]

    gui_vbox do
      show_str :talk
      show_button :send
      show_text :discussion, :width => 400, :flexheight => 1
    end
  end
	
  def rpc_update( session )
    today_date = "--- #{Date.today.strftime('%Y-%m-%d' )} ---"
    last_date = @@disc.data_str.select{|str| str =~ /^---/ }.last
    if not last_date or last_date != today_date
      @@disc.data_str.push today_date
    end
    @@disc.data_str = @@disc.data_str.last( 200 )
    reply( :update, :discussion => @@disc.data_str[-@@box_length..-1].
        reverse.join("\n") ) +
      reply( :focus, :talk)
  end
	
  def rpc_button_send( session, data )
    @@disc.data_str.push( "#{Time.now.strftime('%H:%M')} - " +
        "#{session.owner.login_name}: #{data['talk']}" )
    log_msg "chat", "#{session.owner.login_name} says - #{data._talk}"
    reply( :empty, [:talk] ) +
      rpc_update( session )
  end
end
