require 'mulukhiya-toot-proxy/amazon_uri'
require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class AmazonAsinHandler < Handler
    def exec(source)
      URI.extract(source, ['http', 'https']).each do |link|
        uri = AmazonURI.parse(link)
        next unless uri.shortenable?
        increment!
        source.sub!(uri.to_s, uri.shorten.to_s)
      end
      return source
    end
  end
end
