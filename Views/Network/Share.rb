require 'Helpers.rb'

class NetworkShare < View
  include VTListPane
  
  def layout
    set_data_class :Shares
    
    @order = 50
    @update = true
    @functions_need = [:share]

    @samba = Entities.Statics.get( :NetworkSamba )
    if @samba.data_str.class != Hash
      dputs(4){"Oups - samba is #{@samba.data_str.inspect}"}
      @samba.data_str = {}
    end

    gui_vbox :nogroup do
      gui_hbox do
        gui_vbox :nogroup do
          vtlp_list :shares, :name
          show_button :new, :delete
        end
        gui_vbox :nogroup do
          show_block :config, :width => 200
          show_button :share_save, :change_path, :add_htaccess
        end
        gui_vbox :nogroup do
          show_list_single :users, :width => 200
          show_button :no_access, :read_write, :read_only
        end
      end
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_str :domain, :width => 200
          show_str :hostname
          show_button :samba_save
        end
        gui_vbox :nogroup do
        end
      end
        
      gui_window :msg do
        show_html :msg_txt
        show_button :close
      end
    end
  end
  
  def users_update( session )
    if session and ( share_str = session.s_data[:share] )
      users = Persons.search_by_groups( "share" )
      share = Shares.match_by_share_id( share_str )
      dputs(3){"Users is #{users.inspect} and share is #{share.inspect}"}
      if users and share
        dputs(3){"Acl of #{share.name} is #{share.acl.inspect}"}
        share.acl.collect{|k,v|
          user = Persons.match_by_login_name( k )
          users.delete( user )
          access = v == "ro" ? "read-only" : "read-write"
          name = user.full_name
          name.to_s == 0 and name = user.login_name
          [k, "#{name}: #{access}"]
        }.sort{|a,b| a[1] <=> b[1]} + 
          users.collect{|u|
          [u.login_name, u.full_name ]
        }.sort{|a,b| a[1] <=> b[1]}
      else
        return []
      end
    else
      return []
    end
  end
  
  alias_method :rpc_list_choice_old, :rpc_list_choice
  def rpc_list_choice( session, name, *args )
    dputs( 3 ){ "rpc_list_choice with #{name} - #{args.inspect}" }
    if name == @vtlp_field
      session.s_data[:share] = args[0][name][0]
      dputs(4){"session.s_data is #{session.s_data.inspect}"}
    end
    rpc_list_choice_old( session, name, args[0] )
  end


  def rpc_update( session )
    dputs(4){"Updating samba: #{users_update( session )}"}
    show_users = reply( :hide, :users )
    begin
      if ( share_id = session.s_data[:share] ) and
          (Shares.match_by_share_id( share_id ).public == ["No"])
        show_users = reply( :unhide, :users )
      end
    rescue NoMethodError
    end
    reply( :empty_only, [ :users ] ) +
      reply( :update, 
      :users => users_update( session ) ) +
      %w( domain hostname ).collect{|d|
      reply( :update, d => @samba.data_str[d])
    }.flatten +
      show_users
  end
    
  def rpc_button( session, name, data )
    case name
    when /no_access|read_write|read_only/
      if (user = Persons.match_by_login_name( data["users"][0] )) and
          (share = Shares.match_by_share_id( data['shares'][0] ))          
        case name
        when /no_access/
          share.acl.delete user.login_name
        when /read_write/
          share.acl[user.login_name] = "rw"
        when /read_only/
          share.acl[user.login_name] = "ro"
        end
        dputs(4){"Share.acl is #{share.acl.inspect}"}
        session.s_data[:share] = data['shares'][0]
      else
        return reply(:window_show, :msg ) +
          reply( :update, :msg_txt => "First choose a share<br>" +
            "then a user")
      end
      rpc_update( session )
    when /new/
      rpc_button_new( session, data ) +
        reply( :hide, :users )
    else
      super( session, name, data )
    end
  end
  
  def rpc_button_share_save( session, data )
    ret = rpc_button_save( session, data ) +
      rpc_button_samba_save( session, data )
  end

  def rpc_button_close( session, data )
    reply( :window_hide )
  end
  
  def rpc_button_samba_save( session, data )
    %w( domain hostname ).each{|d|
      dputs(4){"Saving -#{d}- for -#{@samba.data_str.inspect}-"}
      store = data[d] ? data[d] : d
      @samba.data_str[d] = store
    }
    dputs(4){"@samba is now -#{@samba.data_str.inspect}-"}

    Shares.save_config( @samba.data_str['domain'] )
    return []
  end
  
  def rpc_button_add_htaccess( session, data )
    share = Shares.find_by_share_id( data["shares"][0] )
    dputs(3){"Working with #{share}"}
    
    share.add_htaccess
  end

end
  
