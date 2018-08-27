require 'mulukhiya/amazon_uri'
require 'mulukhiya/handler/url_handler'

module MulukhiyaTootProxy
  class AmazonAsinHandler < UrlHandler
    def rewrite(link)
      uri = AmazonURI.parse(link)
      uri.associate_tag = @config.associate_tag if @config['local']['amazon']['affiliate']
      @status.sub!(link, uri.shorten.to_s)
    end

    private

    def rewritable?(link)
      return AmazonURI.parse(link).shortenable?
    end
  end
end
