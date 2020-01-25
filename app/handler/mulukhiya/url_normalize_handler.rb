module Mulukhiya
  class URLNormalizeHandler < URLHandler
    def rewrite(uri)
      source = Ginseng::URI.parse(uri.to_s)
      dest = source.normalize
      @status.sub!(source.to_s, dest.to_s)
      return dest
    end
  end
end
