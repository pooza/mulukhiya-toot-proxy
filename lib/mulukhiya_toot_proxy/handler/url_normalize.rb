module MulukhiyaTootProxy
  class URLNormalizeHandler < URLHandler
    def rewrite(link)
      uri = Ginseng::URI.parse(link).normalize
      @status.sub!(link, uri.to_s)
      return uri.to_s
    end
  end
end
