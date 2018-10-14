require 'mulukhiya/amazon_uri'
require 'mulukhiya/amazon_service'
require 'mulukhiya/url_handler'

module MulukhiyaTootProxy
  class AmazonAsinHandler < UrlHandler
    def rewrite(link)
      uri = AmazonURI.parse(link)
      uri.associate_tag = AmazonService.associate_tag
      @status.sub!(link, uri.shorten.to_s)
    end

    private

    def rewritable?(link)
      return AmazonURI.parse(link).shortenable?
    end
  end
end
