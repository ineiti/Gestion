
class Files < RPCQooxdooPath
  def self.parse_req_res( req, res )
    ddputs( 4 ){ "Files: #{req.inspect}" }
    path, query, addr = req.path, req.query.to_sym, RPCQooxdooHandler.get_ip( req )
    if req.request_method == 'GET'
      filename = path.sub( /^.[^\/]*./, '' )
      res['content-type'] = case filename
      when /js$/i
        'text/javascript'
      when /html$/i
        'text/html'
      end
      ddputs(4){"Request is #{req.inspect}" }
      ddputs(3){"filename is #{filename} - content-type is #{res['content-type']}" }
      return IO.read( 'Files/' + filename )
    end
  end
end
