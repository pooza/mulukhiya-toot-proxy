module MulukhiyaTootProxy
  class URLNormalizeHandler < URLHandler
    def rewrite(link)
      return @status.sub!(link, Ginseng::URI.parse(link).normalize.to_s)
    end
  end
end
