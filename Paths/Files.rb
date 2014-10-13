
class Files < RPCQooxdooPath
  def self.parse_req_res( req, res )
    dputs( 4 ){ "Files: #{req.inspect}" }
    path, query, addr = req.path, req.query.to_sym, RPCQooxdooHandler.get_ip( req )
    if req.request_method == 'GET'
      filename = path.sub( /^.[^\/]*./, '' )
      res['content-type'] = case filename
      when /js$/i
        'text/javascript'
      when /html$/i
        'text/html'
      end
      dputs(4){"Request is #{req.inspect}" }
      dputs(3){"filename is #{filename} - content-type is #{res['content-type']}" }
      return IO.read( 'Files/' + filename )
    end
  end
end
