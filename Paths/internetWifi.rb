class InternetWifi < RPCQooxdooPath
  def self.parse_req_res(req, res)
    ip = RPCQooxdooHandler.get_ip(req)
    path, query = req.path, req.query
    dputs(4) { "InternetWifi: #{req.inspect} - #{req.path} - #{ip}" }
    if req.request_method == 'GET'
      case path
        when /users.cgi/
          return 'mac'
        when /connect.cgi/
          dp query.inspect
          login_name, password = query._user, query._pass
          dp person = Persons.match_by_login_name(login_name)
          person and dputs(3) { "Person is #{person.inspect} and #{person.password}" }
          if person and person.check_pass(password) then
            session = Sessions.create(person)
            session.web_req = req
            session.client_ip = RPCQooxdooHandler.get_ip(req)
            dp session.inspect
            dputs(3) { "Found login #{person.data_get(:person_id)} for #{login_name}" }
            dputs(3) { "Session is #{session.inspect}" }
            log_msg :InternetWifi, "Authenticated person #{person.login_name} from " +
                                     "#{session.client_ip} and redirecting"
          end
          addr = 'admin.profeda.org'
          #addr = 'localhost:3302'
          return self.redirect(addr)
        when /favicon.ico/
          return ''
        when /internetwifi/
          return self.redirect('http://admin.profeda.org')
        else
          dputs(0) { "Error: #{path} in #{req.inspect} is not supported" }
      end
    end
  end

  def self.redirect(address, timeout=0)
    "
<!DOCTYPE HTML>
<html lang='fr-FR'>
    <head>
        <meta charset='UTF-8'>
        <meta http-equiv='refresh' content='#{timeout};url=#{address}'>
        <script type='text/javascript'>
            window.location.href = '#{address}'
        </script>
        <title>Page Redirection</title>
    </head>
    <body>
        If you are not redirected automatically, follow the <a href='#{address}'>link to example</a>
    </body>
</html>"
  end
end

