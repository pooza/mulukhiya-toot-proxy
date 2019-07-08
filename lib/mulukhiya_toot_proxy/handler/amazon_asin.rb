module MulukhiyaTootProxy
  class AmazonASINHandler < URLHandler
    def disable?
      return @config.disable?(underscore_name) if affiliate?
      return super
    rescue Ginseng::ConfigError
      return false
    end

    def rewrite(link)
      uri = AmazonURI.parse(link)
      uri.associate_tag = AmazonService.associate_tag if affiliate?
      @status.sub!(link, uri.shorten.to_s)
    end

    private

    def affiliate?
      return @config['/amazon/affiliate']
    end

    def rewritable?(link)
      return AmazonURI.parse(link).shortenable?
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
