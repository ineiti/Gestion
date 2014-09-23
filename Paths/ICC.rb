# This will be the only InterCenterCommunication-point to "Gestion"
# TODO
# - include Label
# - secure connection
# Implemented:
# - fetch CourseType-definitions
require 'cgi'

class ICC < RPCQooxdooPath
  @@transfers = {}

  def self.parse_req(req)
    dputs_func
    #dputs(4) { "Request: #{req.inspect}" }
    if req.request_method == 'POST'
      path, query, addr = req.path, req.query.to_sym, RPCQooxdooHandler.get_ip(req)
      dputs(4) { "Got query: #{path} - #{query.inspect} - #{addr}" }

      if query._cmdkey == 'start'
        log_msg :ICC, "Got start-query: #{path} - #{query.inspect} - #{addr}"
        d = JSON.parse(query._data).to_sym
        dputs(3) { "d is #{d.inspect}" }
        if (user = Persons.match_by_login_name(d._user)) and
            (user.check_pass(d._pass))
          @@transfers[d._tid] = d.merge(:data => '')
          d._chunks > 0 and return 'OK: send data'
          query._cmdkey = d._tid
          query._data = ''
        else
          dputs(3) { "User #{d._user.inspect} with pass #{d._pass.inspect} unknown" }
          return 'Error: authentification'
        end
      end
      if tr = @@transfers[query._cmdkey]
        dputs(3) { "Found transfer-id #{query._cmdkey}, #{tr._chunks} left" }
        tr._data += query._data
        if (tr._chunks -= 1) <= 0
          if Digest::MD5.hexdigest(tr._data) == tr._md5
            dputs(2) { "Successfully received cmdkey #{tr._cmdkey}" }
            ret = self.data_received(tr)
          else
            dputs(2) { "cmdkey #{tr._cmdkey} transmitted with errors, " +
                "#{Digest::MD5.hexdigest(tr._data)} instead of #{tr._md5}" }
            ret = 'Error: wrong MD5'
          end
          @@transfers.delete query._cmdkey
          return ret
        else
          return "OK: send #{tr._chunks} more chunks"
        end
      end
      return 'Error: must start or use existing cmdkey'
    else # GET-request
      path = /.*\/([^\/]*)\/([^\/]*)$/.match(req.path)
      ddputs(3) { "Path #{req.path} is #{path.inspect}" }
      query = CGI.parse( req.query_string )
      log_msg :ICC, "Got query: #{path.inspect} - #{query}"
      self.request(path[1], path[2], query)
    end
  end

  def self.request(entity_name, m, query_json)
    m =~ /^icc_/ and log_msg :ICC, "Method #{m} includes 'icc_' - probably not what you want"
    method = "icc_#{m}"
    if en = Object.const_get(entity_name)
      ddputs(3) { "Sending #{method} to #{entity_name}" }
      query={}
      query_json.each_pair{|k,v| query[k] = JSON.parse( v.first )}
      ddputs(3){"Found query #{query.inspect}"}
      en.send(method, query)
    else
      log_msg :ICC, "Error: Object #{entity_name} doesn't exist"
    end.to_json
  end

  def self.data_received(tr)
    entity_name, m = tr._method.split('.')
    method = "icc_#{m}"
    Object.const_get(entity_name)
    if en = Object.const_get(entity_name) # and en.respond_to? method
      ddputs(3) { "Sending #{method} to #{entity_name}" }
      en.send(method, tr)
    else
      log_msg :ICC, "Error: Object #{entity_name} has no method #{method}"
    end.to_json
  end

  def self.send_post(url, cmdkey, data, retries: 4)
    path = URI.parse(url)
    post = {:cmdkey => cmdkey, :data => data}
    ddputs(3) { "Sending to #{path.inspect}: #{data.inspect}" }
    err = ''
    (1..retries).each { |i|
      begin
        ret = Net::HTTP.post_form(path, post)
        dputs(4) { "Return-value is #{ret.inspect}, body is #{ret.body}" }
        return ret.body
      rescue Timeout::Error
        dputs(2) { 'Timeout occured' }
        err = 'Error: Timeout occured'
      rescue Errno::ECONNRESET
        dputs(2) { 'Connection reset' }
        err = 'Error: Connection reset'
      end
    }
    return err
  end

  def self.transfer(method, transfer = '', url: ConfigBase.server_uri, slow: false)
    block_size = 4096
    transfer_md5 = Digest::MD5.hexdigest(transfer)
    t_array = []
    while t_array.length * block_size < transfer.length
      start = (block_size * t_array.length)
      t_array.push transfer[start..(start+block_size -1)]
    end

    pos = 0
    dputs(3) { "Going to transfer: #{t_array.inspect}" }
    tid = Digest::MD5.hexdigest(rand.to_s)
    center = Persons.center
    ret = ICC.send_post(url, :start,
                        {:method => method, :chunks => t_array.length,
                         :md5 => transfer_md5, :tid => tid,
                         :user => center.login_name, :pass => center.password_plain,
                         :course => name}.to_json)
    return ret if ret =~ /^Error:/
    ss = @sync_state
    t_array.each { |t|
      @sync_state = "#{ss} #{((pos+1) * 100 / t_array.length).floor}%"
      dputs(3) { @sync_state }
      ret = ICC.send_post(url, tid, t)
      return ret if ret =~ /^Error:/
      slow and sleep 3
      pos += 1
    }
    return ret
  end

  def self.get(entity_name, method, args: {}, url: ConfigBase.server_uri)
    args_json = {}
    args.each_pair{|k,v| args_json[k] = v.to_json}
    dp path = URI.parse("#{url}/#{entity_name}/#{method}?#{URI.encode_www_form(args_json)}")
    ret = JSON::parse(Net::HTTP.get(path))
  end
end
