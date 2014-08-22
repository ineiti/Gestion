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
    @auto_update_async = 10
    @auto_update_send_values = false

    gui_vboxg do
      show_html :replace
      show_str :email
      show_str :talk
      show_button :send
      show_text :discussion, :width => 400, :flexheight => 1, :flexwidth => 1
    end
  end

  def rpc_update_view( session, args = nil )
    super( session, args ) + 
      if get_config( false, :multilogin )
      reply( :update, :email => "anonyme@profeda.org" ) +
        reply( :update, :replace => "<h1>Ajoutez votre courriel!</h1>" )
    else
      reply( :hide, [ :replace, :email ] )
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
    name, ret = if get_config( false, :multilogin ) 
      [data._email, if data._email != "anonyme@profeda.org"
          reply( :hide, :replace )
        end.to_a]
    else
      [session.owner.login_name, []]
    end
    @@disc.data_str.push( "#{Time.now.strftime('%H:%M')} - " +
        "#{name}: #{data._talk}" )
    log_msg "chat", "#{name} says - #{data._talk}"
    ret + reply( :empty_only, [:talk] ) +
      rpc_update( session )
  end
end
