module Mulukhiya
  class AmazonURLHandler < URLHandler
    def rewrite(uri)
      source = AmazonURI.parse(uri.to_s)
      dest = source.clone
      dest = dest.shorten
      @status = @status.sub(source.to_s, dest.to_s)
      return dest
    end

    def rewritable?(uri)
      uri = AmazonURI.parse(uri.to_s) unless uri.is_a?(AmazonURI)
      return uri.shortenable?
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end
  end
end
