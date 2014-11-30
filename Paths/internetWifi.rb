class InternetWifi < RPCQooxdooPath
  def self.parse_req_res(req, res)
    ip = RPCQooxdooHandler.get_ip(req)
    path, query = req.path, req.query
    dputs(4) { "InternetWifi: #{req.inspect} - #{req.path} - #{ip}" }
    if req.request_method == 'GET'
      case path
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
            ddputs(3) { "Found login #{person.data_get(:person_id)} for #{login_name}" }
            ddputs(3) { "Session is #{session.inspect}" }
            log_msg :InternetWifi, "Authenticated person #{person.login_name} from " +
                "#{session.client_ip} and redirecting"
          end
          addr = 'admin.profeda.org'
          #addr = 'localhost:3302'
          return "
<!DOCTYPE HTML>
<html lang='fr-FR'>
    <head>
        <meta charset='UTF-8'>
        <meta http-equiv='refresh' content='1;url=http://#{addr}'>
        <script type='text/javascript'>
            window.location.href = 'http://#{addr}'
        </script>
        <title>Page Redirection</title>
    </head>
    <body>
        If you are not redirected automatically, follow the <a href='http://#{addr}'>link to example</a>
    </body>
</html>"
        else
          dputs(0) { "Error: #{req.inspect} is not supported" }
      end
    end
  end
end

