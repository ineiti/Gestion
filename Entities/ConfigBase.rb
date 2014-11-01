class ConfigBases < Entities
  def add_config
    value_block :vars
    value_str :libnet_uri
    value_str :internet_cash
    value_int :max_upload_size
    value_str :server_url
    value_str :label_url
    value_list_drop :operator, 'Network::Operator.list_names'
    value_entity_account_all :account_activities, :drop, :path
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

    value_block :operator
    value_int :cost_base
    value_int :cost_shared
    value_str :allow_free

    @@functions = %w( network share
    courses course_server course_client
    internet internet_simple internet_captive
    sms_control
    inventory accounting quiz accounting_courses accounting_old
    cashbox email usage_report activities library ).sort.to_sym
    @@functions_base = {:network => [:internet, :share, :internet_only, :email, :sms_control],
                        :internet => [:internet_simple, :internet_captive],
                        :courses => [:course_server, :course_client, :accounting_courses],
                        :accounting => [:accounting_courses],
                        :cashbox => [:accounting_courses],
                        :activities => [:library]
    }
    @@functions_conflict = [[:course_server, :course_client]]
  end

  def migration_4(c)
    if c._functions.index(:internet_libnet)
      c._functions -= [:internet_libnet]
      c._functions += [:internet_captive]
    end
    if ! c.welcome_text || c.welcome_text == ''
      c.welcome_text = get_config('', :welcome_text)
    end
  end

  def migration_3(c)
    c._max_upload_size = 1_000_000
  end

  def migration_2(c)
    dputs(3) { "Migrating in: #{c.inspect} - #{get_config(true, :LibNet, :simulation).inspect}" }
    if get_config(true, :LibNet, :simulation) == false
      dputs(3) { 'Adding LibNet' }
      c._functions += [:internet_libnet]
    end
    c._libnet_uri = get_config('', :LibNet, :URI)
    c._internet_cash = get_config(nil, :LibNet, :internetCash)
    dputs(3) { "Migrating out: #{c.inspect}" }
  end


=begin
  def migrate
    ConfigBases.singleton

    super

    if !$lib_net
      if ConfigBase.has_function? :internet_libnet
        if (uri = ConfigBase.libnet_uri).length > 0
          dputs(2) { "Making DRB-connection to LibNet with #{uri}" }
          require 'drb'
          $lib_net = DRbObject.new nil, uri
          dputs(1) { "Connection is #{$lib_net.status}" }
        else
          require 'LibNet.rb'
          if get_config(false, :LibNet, :simulation)
            dputs(2) { 'Loading simulated LibNet' }
            $lib_net = LibNet.new(true)
          else
            dputs(2) { 'Loading LibNet in live-mode' }
            $lib_net = LibNet.new(false)
          end
        end
      else
        require 'LibNet.rb'
        $lib_net = LibNet.new(true)
        dputs(2) { 'Loading LibNet in simulation-mode' }
      end
    end
  end
=end
end

class ConfigBase < Entity

  def setup_instance
    send_config
  end

  def send_config
    save_block_to_object :captive, Network::Captive
    Network::Captive.clean_config
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
end
