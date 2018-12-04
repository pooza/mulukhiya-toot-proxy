module MulukhiyaTootProxy
  class AmazonImageHandler < ImageHandler
    def updatable?(link)
      uri = AmazonURI.parse(link)
      return false unless uri.amazon?
      return false unless uri.asin.present?
      return false unless uri.image_uri.present?
      return true
    end

    def create_image_uri(link)
      return AmazonURI.parse(link).image_uri
    end
  end
end
