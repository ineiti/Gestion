class ConfigBases < Entities
  self.needs :Accounts

  def add_config
    value_block :vars_narrow
    value_str :keep_idle_free
    value_int :max_upload_size
    value_str :captive_dev

    value_block :vars_wide
    value_str :internet_cash
    value_str :server_url
    value_str :label_url
    value_str :network_actions

    value_block :templates
    value_str :template_dir
    value_str :card_student
    value_str :card_responsible

    value_block :captive
    value_str :prerouting
    value_str :http_proxy
    value_str :allow_dst
    value_str :internal_ips
    value_str :captive_dnat
    value_str :openvpn_allow_double
    value_str :allow_src_direct
    value_str :allow_src_proxy
    value_str :keep_idle_minutes

    value_block :operator
    value_int :cost_base
    value_int :cost_shared
    value_str :allow_free
    value_str :phone_main

    value_block :accounts
    value_entity_account_all :account_activities, :drop, :path
    value_entity_account_all :account_services, :drop, :path
    value_entity_account_all :account_lending, :drop, :path
    value_entity_account_all :account_cash, :drop, :path

    @@functions = %w( network share
    courses course_server course_client
    internet internet_simple internet_captive
    sms_control sms_control_autocharge
    inventory accounting quiz accounting_courses accounting_old
    cashbox email usage_report activities library ).sort.to_sym
    @@functions_base = {:network => [:internet, :share, :internet_only, :email, :sms_control],
                        :internet => [:internet_simple, :internet_captive],
                        :courses => [:course_server, :course_client, :accounting_courses],
                        :accounting => [:accounting_courses],
                        :cashbox => [:accounting_courses],
                        :activities => [:library],
                        :sms_control => [:sms_control_autocharge]
    }
    @@functions_conflict = [[:course_server, :course_client]]
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
    c._max_upload_size = 1_000_000
  end

  def migration_2(c)
    dputs(3) { "Migrating in: #{c.inspect} - #{get_config(true, :LibNet, :simulation).inspect}" }
    dp 'Old libnet-migration'
    dputs(3) { "Migrating out: #{c.inspect}" }
  end

  def migration_3(c)
    exit if c._functions.index('internet_libnet')
  end

  def delete_all(local_only = false)
    super(local_only)
    init
  end

  def init
    ACQooxView.check_db
    cb = ConfigBases.search_all_.first || ConfigBases.create(functions: [])
    migration_5(cb)
  end
end

class ConfigBase < Entity
  def setup_instance
    super
    send_config
  end

  def send_config
    save_block_to_object :captive, Network::Captive
    Network::Captive.clean_config
    ConfigBase.has_function?(:internet_captive) and Network::Captive.setup
    save_block_to_object :operator, Network::Operator
    Network::Operator.clean_config
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
    (Dir.glob("#{template_dir}/*odt") +
        Dir.glob("#{template_dir}/*odg")).
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
