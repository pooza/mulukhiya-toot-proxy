module Mulukhiya
  class SpotifyImageHandler < ImageHandler
    def disable?
      return super || !SpotifyService.config?
    end

    def updatable?(uri)
      uri = SpotifyURI.parse(uri.to_s) unless uri.is_a?(SpotifyURI)
      return false unless uri.spotify?
      return false unless uri.track_id.present?
      return false unless uri.image_uri.present?
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
      return false
    end

    def create_image_uri(uri)
      uri = SpotifyURI.parse(uri.to_s) unless uri.is_a?(SpotifyURI)
      return uri.image_uri
    end
  end
end
