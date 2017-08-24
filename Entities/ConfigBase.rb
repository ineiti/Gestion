class ConfigBases < Entities
  self.needs %w(Accounts)

  def add_config
    @convert_values = true

    value_block :vars_narrow
    value_list_drop :show_passwords, '%w(always lesser students never)'
    value_list_drop :autosave, '%w(true false)'
    value_int :autosave_timer
    value_list_drop :samba_simul, '%w(true false)'
    value_str :samba_config
    value_list_drop :persons_add_del_users, '%w(true false)'
    value_str :persons_adduser_cmd
    value_str :persons_addeduser_cmd

    value_block :vars_wide
    value_str :server_url
    value_str :label_url
    value_str :html_title
    value_str :upload_files

    value_block :templates
    value_str :template_dir
    value_str :diploma_dir
    value_str :exam_dir
    value_str :presence_sheet
    value_str :presence_sheet_small
    value_str :card_student
    value_str :card_responsible

    value_block :captive_conn
    value_str :keep_idle_free
    value_str :keep_idle_minutes
    value_str :captive_dev

    value_block :captive
    value_str :prerouting
    value_str :http_proxy
    value_str :allow_dst
    value_str :internal_ips
    value_str :captive_dnat
    value_str :openvpn_allow_double
    value_str :allow_src_direct
    value_str :allow_src_proxy
    value_str :allow_double

    value_block :operator
    value_int :cost_base
    value_int :cost_shared
    value_list_drop :allow_free, '%w(false true all)'
    value_str :phone_main
    value_str :start_loaded

    value_block :internet
    value_entity_internetClass_empty_all :iclass_default, :drop, :name

    value_block :mobilecontrol
    value_text :connection_cmds_up
    value_text :connection_cmds_down
    value_str :connection_services_up
    value_str :connection_services_down
    value_str :connection_vpns

    value_block :accounts
    value_entity_account :account_activities, :drop, :path
    value_entity_account :account_services, :drop, :path
    value_entity_account :account_lending, :drop, :path
    value_entity_account :account_cash, :drop, :path

    @@functions = %w( network share network_pro
    courses course_server course_client
    files_manage
    internet internet_simple internet_captive
    internet_free_course internet_free_staff
    internet_cyber
    internet_mobile internet_mobile_autocharge
    inventory accounting quiz accounting_courses accounting_old
    plug_admin special special_vnc remote_chat
    cashbox email usage_report activities library ).sort.to_sym
    @@functions_base = {:network => [:internet, :share, :internet_only, :email,
                                     :internet_mobile, :network_pro],
                        :internet => [:internet_simple, :internet_captive,
                                      :internet_free_course, :internet_free_staff,
                                      :internet_mobile, :internet_cyber],
                        :courses => [:course_server, :course_client, :accounting_courses],
                        :accounting => [:accounting_courses, :cashbox],
                        :cashbox => [:accounting_courses, :internet_cyber],
                        :activities => [:library],
                        :special => [:plug_admin, :special_vnc],
                        :internet_mobile => [:internet_mobile_autocharge]
    }
    @@functions_conflict = [[:course_server, :course_client]]
  end

  def migration_10(c)
    c.allow_free = [c.allow_free]
    c.account_activities = c.account_services
  end

  def migration_9(c)
    c.diploma_dir = get_config('Diplomas', :Entities, :Courses, :dir_diplomas)
    c.template_dir = get_config('Diplomas', :Entities, :Courses, :dir_diplomas)
    c.exam_dir = get_config('Exams', :Entities, :Courses, :dir_exas)
    # Old installation had default directory of 'Exas'
    File.exists?('Exas') && c.exam_dir != 'Exas' and FileUtils.mv('Exas', c.exam_dir)
    c.presence_sheet = get_config('presence_sheet.ods',
                                  :Entities, :Courses, :presence_sheet).to_a
    c.presence_sheet_small = get_config('presence_sheet_small.ods',
                                        :Entities, :Courses, :presence_sheet_small).to_a
    c.card_student = get_config('student_card.odg', :Entities, :Persons, :student_card)
    c.persons_adduser_cmd = get_config('', :Entities, :Persons, :adduser_cmd)
    c.persons_addeduser_cmd = get_config('', :Entities, :Persons, :cmd_after_new)
    c.dputs_logall = '/var/log/gestion/gestion.log'
    c.dputs_logfile = '/var/log/gestion/events.log'
    c.dputs_show_time = %w(min)
    c.dputs_silent = %w(false)
    c.dputs_terminal_width = 160
    c.html_title = 'Gestion from Profeda'
    c.autosave = %w(true)
    c.autosave_timer = get_config(60, :autosave, :timer)
    c.openprint_simul = %w(false)
    c.openprint_search = get_config('.*', :OpenPrint, :search_remote)
    c.upload_files = get_config('/tmp', :UploadFiles, :path)
    c.captive_dev = ''
    c.connection_cmds_up = "postqueue -f\n/usr/local/bin/dnsmasq-internet.sh"
    c.connection_cmds_down = '/usr/local/bin/dnsmasq-catchall.sh'
    c.connection_services_up = 'ntpd fetchmail'
    c.connection_services_down = 'fetchmail'
    c.connection_vpns = if (vpns = Dir.glob('/etc/openvpn/vpn-profeda*conf')).length > 0
                          vpns.collect { |v| File.basename v, '.conf' }.join(' ')
                        else
                          nil
                        end
  end

  def migration_8(c)
    c.show_passwords = %w(lesser)
  end

  def migration_7(c)
    c.replace_function(:sms_control, :internet_mobile)
    c.replace_function(:sms_control_autocharge, :internet_mobile_autocharge)
  end

  def migration_6(c)
    c._use_printing = c._use_printing.to_i > 0
  end

  def migration_5(c)
    c.account_services = Accounts.get_by_path_or_create(
        get_config('Root::Income::Services', :Accounting, :service))
    c.account_lending = Accounts.get_by_path_or_create(
        get_config('Root::Lending', :Accounting, :lending))
    c.account_cash = Accounts.get_by_path_or_create(
        get_config('Root::Cash', :Accounting, :cash))
    #dp c
  end

  def migration_4(c)
    if c._functions.index(:internet_libnet)
      c._functions -= [:internet_libnet]
      c._functions += [:internet_captive]
    end
    if !c.welcome_text || c.welcome_text == ''
      c.welcome_text = get_config('', :welcome_text)
    end
  end

  def migration_3(c)
    c.cost_base = 0
    c.cost_shared = 0
    c.allow_free = 'false'
  end

  def migration_2(c)
    c.keep_idle_free = 5
    c.keep_idle_minutes = 3
    c.server_url = 'icc.profeda.org'
    c.label_url = 'label.profeda.org'
  end

  # Migration_1 is taken by QooxView-ConfigBase!
end

class ConfigBase < Entity
  def send_config
    save_block_to_object :captive, Network::Captive
    Network::Captive.clean_config
    ConfigBase.has_function?(:internet_captive) and Network::Captive.setup
    save_block_to_object :operator, Network::Operator
    Network::Operator.clean_config
    if ConfigBase.has_function?(:share)
      Service.enable_start(:samba)
    else
      Service.stop_disable(:samba)
    end
    if ConfigBase.has_function?(:internet_mobile)
      start_mobile_control
      save_block_to_object :mobilecontrol, $MobileControl
      $MobileControl.autocharge = ConfigBase.has_function?(:internet_mobile_autocharge)
    else
      stop_mobile_control
    end
  end

  def replace_function(old, new)
    func = self.functions.to_sym
    if func.index(old.to_sym)
      func -= [old.to_sym]
      func += [new.to_sym]
    end
    self.functions = func
  end

  def start_mobile_control
    return if $MobileControl
    dputs(1) { 'Starting mobile-control' }
    $MobileControl = Network::MobileControl.new

    @mobile_thread = Thread.new {
      state = nil
      loop {
        rescue_all 'Error with MobileControl' do
          $MobileControl.check_connection
          if state != $MobileControl.state_to_s
            dputs(2) { "#{Time.now.strftime('%y%m%d-%H%M')}: #{state = $MobileControl.state_to_s}" }
          end
          sleep 10
        end
      }
    }
  end

  def stop_mobile_control
    if @mobile_thread
      @mobile_thread.kill
      @mobile_thread.join
      @mobile_thread = nil
    end
    $MobileControl = nil
  end

  def server_uri
    server_url =~ /^http/ ? server_url : "http://#{server_url}"
  end

  def get_url(url)
    if url.class == Symbol
      url = ConfigBase.data_get(url)
    end
    url =~ /^https{0,1}:\/\// ? url : "http://#{url}"
  end

  def templates
    Dir.glob("#{template_dir}/*.od?").
        collect { |f| f.sub(/^.*\//, '') }.
        sort
  end

  def template_path(t)
    return '' unless template_dir && card_student && card_responsible
    "#{template_dir}/" +
        case t
          when :card_student
            card_student.first.to_s
          when :card_responsible
            card_responsible.first.to_s
        end
  end

end
