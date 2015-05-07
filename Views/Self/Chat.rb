# To change this template, choose Tools | Templates
# and open the template in the editor.

class SelfChat < View
  def layout
    @@box_length = 40
    @order = 100
    @update = true
    @auto_update_async = 5
    @auto_update_send_values = false

    gui_vboxg do
      gui_vbox :nogroup do
        show_html :replace
        show_str :email
        show_str :talk, :flexwidth => 1
        show_button :send
      end
      gui_vboxg :nogroup do
        show_text :discussion, :flexheight => 1, :flexwidth => 1
      end
    end

    ChatMsgs.wait_max = 3
  end

  def rpc_update_view(session, args = nil)
    super(session, args) +
        if get_config(false, :multilogin)
          reply(:update, :email => 'anonyme@profeda.org') +
              reply(:update, :replace => '<h1>Ajoutez votre courriel!</h1>')
        else
          reply(:hide, [:replace, :email])
        end
  end

  def rpc_update(session)
    ChatMsgs.wait_counter_add
    reply(:update, discussion: ChatMsgs.show_list) +
        reply(:focus, :talk)
  end

  def rpc_button_send(session, data)
    name, ret = if get_config(false, :multilogin)
                  [data._email, if data._email != 'anonyme@profeda.org'
                                  reply(:hide, :replace)
                                end.to_a]
                else
                  [session.owner.login_name, []]
                end
    ChatMsgs.new_msg_send(name, data._talk)
    ret + reply(:empty, [:talk]) +
        rpc_update(session)
  end
end
