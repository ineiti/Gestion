require 'Helpers.rb'

class NetworkShare < View
  include VTListPane
  
  def layout
    set_data_class :Shares
    
    @order = 50
    @update = true

    @samba = Entities.Statics.get( :NetworkSamba )
    if @samba.data_str.class != Hash
      ddputs(4){"Oups - samba is #{@samba.data_str.inspect}"}
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
          show_button :share_save, :change_path
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
      share = Shares.find_by_share_id( share_str )
      dputs(3){"Users is #{users.inspect} and share is #{share.inspect}"}
      if users and share
        dputs(3){"Acl of #{share.name} is #{share.acl.inspect}"}
        share.acl.collect{|k,v|
          user = Persons.find_by_login_name( k )
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
      ddputs(4){"session.s_data is #{session.s_data.inspect}"}
    end
    rpc_list_choice_old( session, name, args[0] )
  end


  def rpc_update( session )
    ddputs(4){"Updating samba: #{users_update( session )}"}
    show_users = reply( :hide, :users )
    begin
      if ( share_id = session.s_data[:share] ) and
          (Shares.find_by_share_id( share_id ).public == ["No"])
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
      if (user = Persons.find_by_login_name( data["users"][0] )) and
          (share = Shares.find_by_share_id( data['shares'][0] ))          
        case name
        when /no_access/
          share.acl.delete user.login_name
        when /read_write/
          share.acl[user.login_name] = "rw"
        when /read_only/
          share.acl[user.login_name] = "ro"
        end
        ddputs(4){"Share.acl is #{share.acl.inspect}"}
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
      ddputs(4){"Saving -#{d}- for -#{@samba.data_str.inspect}-"}
      store = data[d] ? data[d] : d
      @samba.data_str[d] = store
    }
    ddputs(4){"@samba is now -#{@samba.data_str.inspect}-"}

    a = Command::run( "cat Files/smb.conf" )
    a.gsub!( /WORKGROUP/, @samba.data_str['domain'] )
    a.gsub!( /SERVER/, "Profeda-server on #{@samba.data_str['domain']}" )
    a += "\n"
    Shares.search_all.each{|sh|
      a += "\n\n[#{sh.name}]\n  path = #{sh.path}\n  comment = #{sh.comment}\n"
      if sh.public == ["Yes"]
        a += "  guest ok = yes\n  writeable = yes\n"
      else
        read = []
        write = []
        dputs(4){"sh is #{sh.class}"}
        sh.acl.class == Hash and sh.acl.each{|k,v|
          dputs(4){"Found #{k}: #{v}"}
          case v
          when /rw/
            write.push k
          when /ro/
            read.push k
          end
        }
        a += "  read list = #{read.join(',')}\n  write list = #{write.join(',')}\n" +
          "  valid users = #{ ( read + write ).uniq.join(',')}\n"
      end
      a += "  create mask = 741\n  map archive = yes\n  map system = yes\n" +
        "  map hidden = yes\n"
    }
    if not get_config( false, :Samba, :simulation )
      file_smb = "#{get_config( '/etc/samba', :Samba, :config_dir )}/smb.conf"
      File.open( file_smb, 'w' ){|f|
        f.write( a )
      }

      if File.exists? "/etc/init.d/samba"
        Command::run( "/etc/init.d/samba restart")
      elsif File.exists? "/etc/init.d/smb"
        Command::run( "/etc/init.d/smb restart")
        Command::run( "/etc/init.d/nmb restart")
      else
        dputs(0){"Couldn't restart samba as there was no init.d-file"}
      end
    end

    return []
  end

end
  
