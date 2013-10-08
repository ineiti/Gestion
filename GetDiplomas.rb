
class GetDiplomas < RPCQooxdooPath
  def self.parse_req_res( req, res )
    dputs( 4 ){ "GetDiplomas: #{req.inspect}" }
    path, query, addr = req.path, req.query.to_sym, req.peeraddr[2]
    if req.request_method == "GET"
      ddputs(4){req.inspect}
      res['content-type'] = "application/pdf"
      return IO.read( Courses.dir_diplomas + "/" + path.sub( /^.[^\/]*./, '' ) ).
        force_encoding( "ASCII-8BIT" )
    end
  end
end
