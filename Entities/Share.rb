# Holds share for samba

class Shares < Entities
  def setup_data
    value_block :config
    value_str :name
    value_str :path
    value_str :comment
    value_str :force_user
    value_str :force_group
    #value_text :args
    value_list_drop :public, "%w( No Read ReadWrite )"
    
    value_block :acl
    value_str :acl
  end
  
  def migration_1( s )
    s.public = [ s.public.first == "Yes" ? "ReadWrite" : "No" ]
  end

  def save_config( domain )
    a = Command::run( "cat Files/smb.conf" )
    a.gsub!( /WORKGROUP/, domain )
    a.gsub!( /SERVER/, "Profeda-server on #{domain}" )
    a += "\n"
    Shares.search_all.each{|sh|
      a += "\n\n[#{sh.name}]\n  path = #{sh.path}\n  comment = #{sh.comment}\n"
      case sh.public.first
      when "Read"
        a += "  guest ok = yes\n  writeable = no\n"
      when "ReadWrite"
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
      if sh.force_user.to_s.length > 0
        a += "  force user = #{sh.force_user}\n"
      end
      if sh.force_group.to_s.length > 0
        a += "  force group = #{sh.force_group}\n"
      end
      #a += "  hide files = /~$*/*.tmp/\n   blocking locks = no\n"
      #a += "  create mask = 741\n  map archive = yes\n  map system = yes\n" +
      #  "  map hidden = yes\n"
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
  end
end

class Share < Entity
  def setup_instance
    if not self.acl
      self.acl = {}
    end
  end
end