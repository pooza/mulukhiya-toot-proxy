require 'addressable/uri'
require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class UrlNormalizeHandler < Handler
    def exec(body, headers = {})
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        increment!
        body['status'].sub!(link, Addressable::URI.parse(link).normalize.to_s)
      end
      return body
    end
  end
end
