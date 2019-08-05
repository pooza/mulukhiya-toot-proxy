module MulukhiyaTootProxy
  class ItunesURLHandler < URLHandler
    def rewrite(link)
      uri = ItunesURI.parse(link).shorten
      @status.sub!(link, uri.to_s)
      return uri
    end

    private

    def rewritable?(link)
      return ItunesURI.parse(link).shortenable?
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
