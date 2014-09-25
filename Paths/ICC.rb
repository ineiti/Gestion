# This will be the only InterCenterCommunication-point to "Gestion"
# TODO
# - secure connection
# Implemented:
# - simple get-function
# - longer post-function
# - put json around everything
require 'cgi'

# Ouch - old version of ActiveSupport, needs this patch
module ActiveSupport::JSON::Encoding
  def self.escape(string)
    if string.respond_to?(:force_encoding)
      string = string.encode(::Encoding::UTF_8, :undef => :replace).force_encoding(::Encoding::BINARY)
    end
    json = string.gsub(escape_regex) { |s| ESCAPED_CHARS[s] }
    json = %("#{json}")
    json.force_encoding(::Encoding::UTF_8) if json.respond_to?(:force_encoding)
    json
  end
end

class ICC < RPCQooxdooPath
  @@transfers = {}

  def self.response(code, msg)
    {code: code, msg: msg}.to_json
  end

  def self.parse_req(req)
    #dputs(4) { "Request: #{req.inspect}" }
    #dputs_func
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
          d._chunks > 0 and return self.response('OK', 'send data')
          query._cmdkey = d._tid
          query._data = ''
        else
          dputs(3) { "User #{d._user.inspect} with pass #{d._pass.inspect} unknown" }
          return self.response('Error', 'authentication')
        end
      end
      if tr = @@transfers[query._cmdkey]
        dputs(3) { "Found transfer-id #{query._cmdkey}, #{tr._chunks} left" }
        tr._data += query._data
        if (tr._chunks -= 1) <= 0
          if Digest::MD5.hexdigest(tr._data) == tr._md5
            dputs(2) { "Successfully received cmdkey #{tr._cmdkey}" }
            ret = self.response('OK', self.data_received(tr))
          else
            dputs(2) { "cmdkey #{tr._cmdkey} transmitted with errors, " +
                "#{Digest::MD5.hexdigest(tr._data)} instead of #{tr._md5}" }
            ret = self.response('Error', 'wrong MD5')
          end
          @@transfers.delete query._cmdkey
          return ret
        else
          return self.response('OK', "send #{tr._chunks} more chunks")
        end
      end
      return self.response('Error', 'must start or use existing cmdkey')
    else # GET-request
      path = /.*\/([^\/]*)\/([^\/]*)$/.match(req.path)
      dputs(3) { "Path #{req.path} is #{path.inspect}" }
      query = CGI.parse(req.query_string)
      log_msg :ICC, "Got query: #{path.inspect} - #{query}"
      self.request(path[1], path[2], query)
    end
  end

  def self.request(entity_name, m, query_json)
    m =~ /^icc_/ and log_msg :ICC, "Method #{m} includes 'icc_' - probably not what you want"
    method = "icc_#{m}"
    if en = Object.const_get(entity_name)
      dputs(3) { "Sending #{method} to #{entity_name}" }
      query={}
      query_json.each_pair { |k, v| query[k] = JSON.parse(v.first) }
      dputs(3) { "Found query #{query.inspect}" }
      self.response('OK', en.send(method, query))
    else
      self.response('Error', log_msg(:ICC, "Object #{entity_name} doesn't exist"))
    end
  end

  def self.data_received(tr)
    if tr._method.sub!(/^json@/, '')
      tr._data = JSON.parse(tr._data).first
    end
    entity_name, m = tr._method.split('.')
    method = "icc_#{m}"
    Object.const_get(entity_name)
    if en = Object.const_get(entity_name) # and en.respond_to? method
      dputs(3) { "Sending #{method} to #{entity_name}" }
      en.send(method, tr)
    else
      log_msg :ICC, "Error: Object #{entity_name} has no method #{method}"
    end
  end

  def self.send_post(url, cmdkey, data, retries: 4)
    path = URI.parse(url)
    post = {:cmdkey => cmdkey, :data => data}
    dputs(3) { "Sending to #{path.inspect}: #{data.inspect}" }
    err = ''
    (1..retries).each { |i|
      begin
        ret = Net::HTTP.post_form(path, post)
        dputs(4) { "Return-value is #{ret.inspect}, body is #{ret.body}" }
        return JSON.parse(ret.body)
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

  def self.transfer(method, transfer = '', url: ConfigBase.server_uri, json: true)
    block_size = 4096
    if json
      method.prepend 'json@'
      transfer = [transfer].to_json
    end

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
                         :user => center.login_name, :pass => center.password_plain}.to_json)
    return ret if ret._code == 'Error'
    ss = @sync_state
    t_array.each { |t|
      @sync_state = "#{ss} #{((pos+1) * 100 / t_array.length).floor}%"
      dputs(3) { @sync_state }
      ret = ICC.send_post(url, tid, t)
      return ret if ret =~ /^Error:/
      pos += 1
    }
    return ret
  end

  def self.get(entity_name, method, args: {}, url: ConfigBase.server_uri)
    args_json = {}
    args.each_pair { |k, v| args_json[k] = v.to_json }
    path = URI.parse("#{url}/#{entity_name}/#{method}?#{URI.encode_www_form(args_json)}")
    JSON::parse(Net::HTTP.get(path))
  end
end
