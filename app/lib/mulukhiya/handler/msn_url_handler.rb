module Mulukhiya
  class MsnURLHandler < URLHandler
    def rewrite(uri)
      source = MsnURI.parse(uri.to_s)
      dest = source.shorten
      @status.sub!(source.to_s, dest.to_s)
      return dest
    end

    def rewritable?(uri)
      uri = MsnURI.parse(uri.to_s) unless uri.is_a?(MsnURI)
      return uri.shortenable?
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end
  end
end
