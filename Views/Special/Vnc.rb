class SpecialVNC < View
  def layout
    @order = 100
    @auto_update = 5
    @update = true

    gui_vbox do
      show_str :ip
      show_str :password
      show_str_ro :status
      show_button :start_x
    end
  end

  def rpc_update(session)
    reply(:update, password: @static._password) +
        reply(:update, ip: session.client_ip) +
        rpc_update_with_values(nil, nil)
  end

  def rpc_update_with_values(session, data)
    reply(:update, status: System.run_str('pgrep -af vnc'))
  end

  def rpc_button_start_x(session, data)
    @static._password = data._password
    if Service.system == :ArchLinux
      System.run_str("echo #{data._password} | vncpasswd -f > /root/.vnc/passwd")
      IO.write('/root/.xinitrc',
               "xset -dpms; xset s off
x0vncserver -passwordfile ~/.vnc/passwd &
vncviewer -fullscreen -shared -viewonly -passwd=/root/.vnc/passwd #{data._ip}")
      System.run_bool('killall -9 xinit')
      System.run_bool('killall -9 Xorg')
      Service.start 'startx@root'
    end
  end
end