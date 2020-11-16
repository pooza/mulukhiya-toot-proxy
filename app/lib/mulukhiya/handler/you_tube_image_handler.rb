module Mulukhiya
  class YouTubeImageHandler < ImageHandler
    def disable?
      return super || !YouTubeService.config?
    end

    def handle_pre_toot(body, params = {})
      params[:trim_times] = 2
      return super
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
