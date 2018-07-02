require 'addressable/uri'
require 'mulukhiya/handler/url_handler'

module MulukhiyaTootProxy
  class UrlNormalizeHandler < UrlHandler
    def rewrite(link)
      return @status.sub!(link, Addressable::URI.parse(link).normalize.to_s)
    end
  end
end
