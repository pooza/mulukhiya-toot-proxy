module MulukhiyaTootProxy
  class AmazonImageHandler < ImageHandler
    def updatable?(link)
      uri = AmazonUri.parse(link)
      return false unless uri.amazon?
      return false unless uri.asin.present?
      return false unless uri.image_uri.present?
      return true
    end

    def create_image_container(link)
      return AmazonUri.parse(link)
    end
  end
end
