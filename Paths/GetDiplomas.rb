
class GetDiplomas < RPCQooxdooPath
  def self.parse_req_res( req, res )
    dputs( 4 ){ "GetDiplomas: #{req.inspect}" }
    path, query, addr = req.path, req.query.to_sym, RPCQooxdooHandler.get_ip( req )
    if req.request_method == 'GET'
      filename = path.sub( /^.[^\/]*./, '' )
      res['content-type'] = case filename
      when /pdf$/i
        'application/pdf'
      when /png$/i
        'image/png'
      end
      dputs(4){"Request is #{req.inspect}" }
      dputs(3){"filename is #{filename} - content-type is #{res['content-type']}" }
      return IO.read( Courses.dir_diplomas + '/' + filename ).
        force_encoding('ASCII-8BIT')
    end
  end
end
