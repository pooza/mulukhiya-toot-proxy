require 'mulukhiya/uri/spotify'
require 'mulukhiya/image_handler'

module MulukhiyaTootProxy
  class SpotifyImageHandler < ImageHandler
    def updatable?(link)
      uri = SpotifyURI.parse(link)
      return false unless uri.spotify?
      return false unless uri.track_id.present?
      return false unless uri.image_uri.present?
      return true
    end

    def create_image_container(link)
      return SpotifyURI.parse(link)
    end
  end
end
