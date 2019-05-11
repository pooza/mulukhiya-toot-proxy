module MulukhiyaTootProxy
  class AmazonASINHandler < URLHandler
    def rewrite(link)
      uri = AmazonURI.parse(link)
      uri.associate_tag = AmazonService.associate_tag if @config['/amazon/affiliate']
      @status.sub!(link, uri.shorten.to_s)
    end

    private

    def rewritable?(link)
      return AmazonURI.parse(link).shortenable?
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
