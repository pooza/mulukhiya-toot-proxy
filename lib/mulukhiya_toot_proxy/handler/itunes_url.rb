module MulukhiyaTootProxy
  class ItunesURLHandler < URLHandler
    def rewrite(link)
      @status.sub!(link, ItunesURI.parse(link).shorten.to_s)
    end

    private

    def rewritable?(link)
      return ItunesURI.parse(link).shortenable?
    end
  end
end
