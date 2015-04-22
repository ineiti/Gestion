class NetworkBlock < View
  def layout
    @functions_need = [:network]
    @order = 100
    @blocking = Entities.Statics.get(:NetworkBlock)
    @blocking.data_str.class != Array and @blocking.data_str = []
    update_block(@blocking.data_str)

    @hosts = Entities.Statics.get(:NetworkBlockHosts)
    @hosts.data_str.class != String and @hosts.data_str = ''

    gui_hbox do
      gui_vboxg :nogroup do
        show_text :hosts, flexheight: 1
        show_button :update
        show_list :blocked, 'View.NetworkBlock.list_dhcp', :width => 400
        show_button :block
      end
    end
  end

  def update_block(ips)
    Network::Captive.block ips.collect { |ip| ip.sub(/ .*/, '') }
  end

  def write_block(file, l)
    #dputs_func
    list = l.to_s.split("\n").collect { |s| s.gsub(/ /, '') }
    dputs(3) { "Writing block #{list.inspect}" }
    file.write(list.compact.collect { |h|
                 address = "address=/#{h}/127.0.0.1\n"
                 dputs(3) { "Outputting #{address}" }
                 address
               }.join)
  end

  def update_dnsmasq_file(list, file)
    block_wrote = false
    tmpfile = "/tmp/#{File.basename(file)}.tmp"
    FileUtils.cp file, tmpfile
    File.open(file, 'w') { |f|
      IO.readlines(tmpfile).each { |li|
        l = li.chomp
        dputs(3) { "Doing line #{l}" }
        case l
          when /^(#*)address.*(\/[^\/]*)$/
            dputs(3) { "#{$1} - #{$2} - #{l}" }
            f.write(l + "\n") if ($1 == '#' || $2 != '/127.0.0.1')
            write_block(f, list) unless block_wrote
            block_wrote = true
          else
            f.write(l + "\n")
        end
      }
      # Add to end of file if not written yet
      write_block(f, list) unless block_wrote
    }
  end

  def update_dnsmasq(list)
    #dputs_func
    %w( /etc/dnsmasq.conf.orig /etc/dnsmasq.conf /tmp/dns.test).each do |f|
      if File.exists? f
        dputs(3) { "Found dnsmasq at #{f}" }
        update_dnsmasq_file(list, f)
      end
    end
  end

  def list_dhcp
    `cut -d " " -f 3,4 /var/lib/misc/dnsmasq.leases`.split("\n")
  end

  def rpc_update_view(session)
    super(session) +
        reply(:update, :blocked => @blocking.data_str, :hosts => @hosts.data_str)
  end

  def rpc_button_block(session, data)
    update_block(@blocking.data_str = data._blocked)
  end

  def rpc_button_update(session, data)
    update_dnsmasq(@hosts.data_str = data._hosts)
    Service.restart :dnsmasq
  end
end
