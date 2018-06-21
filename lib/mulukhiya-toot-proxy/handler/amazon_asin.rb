require 'mulukhiya-toot-proxy/amazon_uri'
require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class AmazonAsinHandler < Handler
    def exec(source)
      source.scan(%r{https?://[^ ]+}).each do |link|
        uri = AmazonURI.parse(link)
        next unless uri.shortenable?
        increment!
        source.sub!(link, uri.shorten.to_s)
      end
      return source
    end
  end
end
