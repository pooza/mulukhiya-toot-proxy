module Mulukhiya
  class YouTubeImageHandler < ImageHandler
    def disable?
      return super || !YouTubeService.config?
    end

    def updatable?(uri)
      uri = VideoURI.parse(uri.to_s) unless uri.is_a?(VideoURI)
      return false unless uri.music?
      return false unless uri.image_uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end

    def create_image_uri(uri)
      uri = VideoURI.parse(uri.to_s) unless uri.is_a?(VideoURI)
      return uri.image_uri
    end
  end
end
