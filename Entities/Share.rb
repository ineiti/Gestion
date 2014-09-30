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
    value_list_drop :public, '%w( No Read ReadWrite )'
    
    value_block :acl
    value_str :acl
  end
  
  def migration_1( s )
    s.public = [ s.public.first == 'Yes' ? 'ReadWrite' : 'No']
  end

  def save_config( domain )
    a = System.run_str('cat Files/smb.conf')
    a.gsub!( /WORKGROUP/, domain )
    a.gsub!( /SERVER/, "Profeda-server on #{domain}" )
    a += "\n"
    Shares.search_all.each{|sh|
      a += "\n\n[#{sh.name}]\n  path = #{sh.path}\n  comment = #{sh.comment}\n"
      valid_users = []
      if sh.force_user.to_s.length > 0
        a += "  force user = #{sh.force_user}\n"
        valid_users.push sh.force_user
      end
      if sh.force_group.to_s.length > 0
        a += "  force group = #{sh.force_group}\n"
        valid_users.push sh.force_group
      end
      case sh.public.first
      when 'Read'
        a += "  guest ok = yes\n  writeable = no\n"
      when 'ReadWrite'
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
          "  valid users = #{ ( read + write + valid_users ).uniq.join(',')}\n"
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

      if File.exists? '/etc/init.d/samba'
        System.run_str('/etc/init.d/samba restart')
      elsif File.exists? '/etc/init.d/smb'
        System.run_str('/etc/init.d/smb restart')
        System.run_str('/etc/init.d/nmb restart')
      elsif File.exists? '/etc/systemd'
        System.run_str('systemctl restart smbd nmbd')
      else
        dputs(0){"Error: Couldn't restart samba as there was no init.d-file"}
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
  
  def add_htaccess
    if File.exists? path
      File.open( "#{path}/.htaccess", "w" ){|f|
        f << "AuthType Basic
AuthName 'Restricted Access'
AuthUserFile '#{path}/.htpasswd'
Require valid-user
"
      }
      File.exists? passfile = "#{path}/.htpasswd" and
        FileUtils.rm passfile
      if acl.class == Hash 
        acl.each{|k,v|
          dputs(4){"Adding #{k} to htpasswd"}
          case v
          when /rw|ro/
            dputs(4){"Really adding #{k} to #{passfile}"}
            user = Persons.find_by_login_name( k )
            %x[ htpasswd -bnd #{user.login_name} "#{user.password_plain }" >> #{passfile} ]
          end
        }
      end
    end
  end
end
