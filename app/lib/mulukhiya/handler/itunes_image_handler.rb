module Mulukhiya
  class ItunesImageHandler < ImageHandler
    def updatable?(uri)
      uri = ItunesURI.parse(uri.to_s) unless uri.is_a?(ItunesURI)
      return false unless uri.itunes?
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
