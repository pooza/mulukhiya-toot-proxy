module MulukhiyaTootProxy
  class AmazonAsinHandler < UrlHandler
    def rewrite(link)
      uri = AmazonUri.parse(link)
      uri.associate_tag = AmazonService.associate_tag
      @status.sub!(link, uri.shorten.to_s)
    end

    private

    def rewritable?(link)
      return AmazonUri.parse(link).shortenable?
    end
  end
end
