class ConfigBases < Entities
  def add_config
    value_block :vars
    value_str :libnet_uri
    value_str :internet_cash
    value_int :max_upload_size
    value_str :server_url
    value_str :label_url
    value_entity_account_all :account_activities, :drop, :path

    @@functions = %w( network internet share 
    courses course_server course_client internet_simple
    internet_libnet sms_control
    inventory accounting quiz accounting_courses accounting_old
    cashbox email usage_report activities library ).sort.to_sym
    @@functions_base = {:network => [:internet, :share, :internet_only, :email],
                        :internet => [:internet_simple, :internet_libnet],
                        :courses => [:course_server, :course_client, :accounting_courses],
                        :accounting => [:accounting_courses],
                        :cashbox => [:accounting_courses],
                        :activities => [:library]
    }
    @@functions_conflict = [[:course_server, :course_client]]
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
end

class ConfigBase < Entity
  def server_uri
    server_url =~ /^http/ ? server_url : "http://#{server_url}"
  end

  def get_url(url)
    if url.class == Symbol
      url = ConfigBase.data_get( url )
    end
    url =~ /^https{0,1}:\/\// ? url : "http://#{url}"
  end
end
