module Mulukhiya
  class YouTubeImageHandler < ImageHandler
    def toggleable?
      return false unless YouTubeService.config?
      return super
    end

    def trim_times
      return 2
    end

    def updatable?(uri)
      uri = YouTubeURI.parse(uri.to_s) unless uri.is_a?(YouTubeURI)
      return false unless uri.music?
      return false unless @image_uris[uri.to_s] = uri.image_uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end

    def create_image_uri(uri)
      return @image_uris[uri.to_s]
    end
  end
end
