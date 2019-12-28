module MulukhiyaTootProxy
  class AmazonImageHandler < ImageHandler
    def disable?
      return super || !AmazonService.config?
    end

    def updatable?(link)
      uri = AmazonURI.parse(link)
      return false unless uri.amazon?
      return false unless uri.asin.present?
      return false unless uri.image_uri.present?
      return true
    rescue => e
      Slack.broadcast(e)
      @logger.error(e)
      return false
    end

    def create_image_uri(link)
      return AmazonURI.parse(link).image_uri
    end
  end
end
