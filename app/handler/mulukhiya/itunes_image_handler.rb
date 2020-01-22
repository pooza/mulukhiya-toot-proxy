module Mulukhiya
  class ItunesImageHandler < ImageHandler
    def updatable?(link)
      uri = ItunesURI.parse(link)
      return false unless uri.itunes?
      return false unless uri.track_id.present?
      return false unless uri.image_uri.present?
      return true
    rescue => e
      Slack.broadcast(e)
      @logger.error(e)
      return false
    end

    def create_image_uri(link)
      return ItunesURI.parse(link).image_uri
    end
  end
end
