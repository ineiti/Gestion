
class Exas < RPCQooxdooPath
  def self.parse_req_res( req, res )
    dputs( 4 ){ "Exas: #{req.inspect}" }
    path, query, addr = req.path, req.query.to_sym, RPCQooxdooHandler.get_ip( req )
    if req.request_method == 'GET'
      filename = path.sub( /^.[^\/]*./, '' )
      res['content-type'] = 'data/binary'
      dputs(4){"Request is #{req.inspect}" }
      dputs(3){"filename is #{filename} - content-type is #{res['content-type']}" }
      # TODO: avoid path-traversing exploit
      return IO.read( "#{Courses.dir_exas}/#{filename}" )
    end
  end
end
