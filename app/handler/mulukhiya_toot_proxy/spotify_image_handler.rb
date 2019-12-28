module MulukhiyaTootProxy
  class SpotifyImageHandler < ImageHandler
    def disable?
      return super || !SpotifyService.config?
    end

    def updatable?(link)
      uri = SpotifyURI.parse(link)
      return false unless uri.spotify?
      return false unless uri.track_id.present?
      return false unless uri.image_uri.present?
      return true
    rescue => e
      Slack.broadcast(e)
      @logger.error(e)
      return false
    end

    def create_image_uri(link)
      return SpotifyURI.parse(link).image_uri
    end
  end
end
