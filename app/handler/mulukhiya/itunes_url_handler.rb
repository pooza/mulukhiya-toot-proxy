module Mulukhiya
  class ItunesURLHandler < URLHandler
    def rewrite(uri)
      source = ItunesURI.parse(uri.to_s)
      dest = source.shorten
      @status.sub!(source.to_s, dest.to_s)
      return dest
    end

    private

    def rewritable?(uri)
      uri = ItunesURI.parse(uri.to_s) unless uri.is_a?(ItunesURI)
      return uri.shortenable?
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
