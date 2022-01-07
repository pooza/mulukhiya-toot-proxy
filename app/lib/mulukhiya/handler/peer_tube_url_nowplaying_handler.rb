module Mulukhiya
  class PeerTubeURLNowplayingHandler < NowplayingHandler
    def disable?
      return super
    end

    def create_uri(keyword)
      return PeerTubeURI.parse(keyword)
    end
  end
end
