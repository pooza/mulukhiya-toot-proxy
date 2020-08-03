module Mulukhiya
  class AmazonImageHandler < ImageHandler
    def disable?
      return super || !AmazonService.config?
    end

    def updatable?(uri)
      uri = AmazonURI.parse(uri.to_s) unless uri.is_a?(AmazonURI)
      return false unless uri.amazon?
      return false unless uri.image_uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end

    def create_image_uri(uri)
      uri = AmazonURI.parse(uri.to_s) unless uri.is_a?(AmazonURI)
      return uri.image_uri
    end
  end
end
