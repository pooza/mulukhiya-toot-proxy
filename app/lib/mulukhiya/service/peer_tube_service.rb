module Mulukhiya
  class PeerTubeService
    include Package

    def initialize(host)
      @http = HTTP.new
      @http.base_uri = "https://#{host}"
    end

    def lookup(id)
      return @http.get(File.join(config['/service/peer_tube/urls/api/video'], id)).parsed_response
    end
  end
end
