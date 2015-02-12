class AdminPrinter < View
  def layout
    @order = 550
    @cups_dir = '/etc/cups'
    @visible = false

    gui_hbox do
      gui_vbox do
        show_list :printers, :single, :flexheight => 1
        show_button :delete, :add
      end
      gui_vbox do
        show_str :cups_name
        show_str :device
        show_str :driver
        show_button :save
      end
    end
  end

  def get_printers
    printers = "#{cups_dir}/printers.conf"
    return [] unless File.exists? printers
    config = IO.read(printers).split(/^<\/Printer>/)
    config.collect{|c|
      cl = c.split("\n")
      name = cl.select{|l| l =~ /^<Printer/}.match(/^<Printer (.*)>/)[0]
      device = cl.select{|l| l =~ /^DeviceURI/}.match(/^DeviceURI (.*)>/)[0]
      driver = cl.select{|l| l =~ /^DeviceURI/}.match(/^DeviceURI (.*)>/)[0]
    }
  end

  def rpc_show(session)
    reply(:empty_all) +
        reply(:update, :printers => get_printers )
  end
end