# To change this template, choose Tools | Templates
# and open the template in the editor.

class SelfChat < View
  def layout
    @@disc = Entities.Statics.get( :SelfChat )
    @@disc.data_str.length < 20 and @@disc.data_str = Array.new(20, "")
    @order = 100
    @update = true
    @auto_update = 10
    @auto_update_send_values = false
    @functions_need = [:network]

    gui_vbox do
      show_text :discussion, :width => 400
      show_str :talk
      show_button :send
    end
  end
	
  def rpc_update( session )
    today_date = "--- #{Date.today.strftime('%Y-%m-%d' )} ---"
    last_date = @@disc.data_str.select{|str| str =~ /^---/ }.last
    if not last_date or last_date != today_date
      @@disc.data_str.push today_date
    end
    @@disc.data_str = @@disc.data_str.last( 200 )
    reply( :update, :discussion => @@disc.data_str[-20..-1].join("\n") ) +
      reply( :focus, :talk)
  end
	
  def rpc_button_send( session, data )
    @@disc.data_str.push( "#{Time.now.strftime('%H:%M')} - " +
     "#{session.owner.login_name}: #{data['talk']}" )
    reply( :empty, [:talk] ) +
      rpc_update( session )
  end
end
