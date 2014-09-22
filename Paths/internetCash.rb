

class InternetCash < RPCQooxdooPath
  def self.parse_req_res(req, res)
    ip = RPCQooxdooHandler.get_ip( req )
    query = req.query
    dputs(4) { "InternetCash: #{req.inspect} - #{req.path} - #{ip}" }
    if req.request_method == 'GET'
      case req.path
        when /fetch_users/
          user_list = []
          Persons.search_all.each { |p|
            credit = 0
            if p.internet_credit.to_i > 0
              credit = p.internet_credit.to_i
              p.internet_credit = 0
            end
            free = Permission.can_view(p.permissions, 'FlagInternetFree') or
                Internet.active_course_for(p)
            if free or credit > 0
              dputs(3) { "Putting #{p.login_name} with credit #{credit} - #{free.inspect}" }
              user_list.push [p.login_name, p.password, credit, free]
            end
          }
          return user_list.to_json
        when /update_connection/
          return Internet.update_connection( ip, query._user )
        else
          dputs(0) { "Error: #{req.inspect} is not supported" }
      end
    end
  end
end

