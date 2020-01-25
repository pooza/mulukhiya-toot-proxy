module Mulukhiya
  class ItunesImageHandler < ImageHandler
    def updatable?(uri)
      uri = ItunesURI.parse(uri.to_s) unless uri.is_a?(ItunesURI)
      return false unless uri.itunes?
      return false unless uri.track_id.present?
      return false unless uri.image_uri.present?
      return true
    rescue => e
      Slack.broadcast(e)
      @logger.error(e)
      return false
    end

    def create_image_uri(uri)
      uri = ItunesURI.parse(uri.to_s) unless uri.is_a?(ItunesURI)
      return uri.image_uri
    end
  end
end
