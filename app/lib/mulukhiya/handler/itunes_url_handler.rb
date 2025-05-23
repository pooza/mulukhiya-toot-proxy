module Mulukhiya
  class ItunesURLHandler < URLHandler
    def rewrite(uri)
      source = ItunesURI.parse(uri.to_s)
      dest = source.shorten
      @status = @status.sub(source.to_s, dest.to_s)
      return dest
    end

    def rewritable?(uri)
      uri = ItunesURI.parse(uri.to_s) unless uri.is_a?(ItunesURI)
      return uri.shortenable?
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end
  end
end
