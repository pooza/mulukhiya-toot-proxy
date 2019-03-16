module MulukhiyaTootProxy
  class ItunesURLHandler < URLHandler
    def rewrite(link)
      @status.sub!(link, ItunesURL.parse(link).shorten.to_s)
    end

    private

    def rewritable?(link)
      return ItunesURL.parse(link).shortenable?
    end
  end
end
