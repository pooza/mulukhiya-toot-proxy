module Mulukhiya
  class AmazonURLHandler < URLHandler
    def rewrite(link)
      uri = AmazonURI.parse(link)
      uri.associate_tag = nil
      uri.associate_tag = AmazonService.associate_tag if affiliate?
      @status.sub!(link, uri.shorten.to_s)
      return uri.shorten
    end

    private

    def affiliate?
      return false if sns.account.config['/amazon/affiliate'].is_a?(FalseClass)
      return false unless @config['/amazon/affiliate']
      return true
    rescue => e
      @logger.error(e)
      return true
    end

    def rewritable?(link)
      return AmazonURI.parse(link).shortenable?
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
