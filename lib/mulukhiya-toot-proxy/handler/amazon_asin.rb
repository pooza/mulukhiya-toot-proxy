require 'addressable/uri'
require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class AmazonAsinHandler < Handler
    def exec(source)
      URI.extract(source, ['http', 'https']).each do |link|
        uri_source = Addressable::URI.parse(link)
        next unless uri_source.host == 'www.amazon.co.jp'
        next unless (matches = uri_source.path.match(%r{/dp/[A-Za-z0-9]+}))
        increment!
        uri_dest = uri_source.clone
        uri_dest.path = matches[0]
        uri_dest.query = nil
        uri_dest.fragment = nil
        source.sub!(uri_source.to_s, uri_dest.to_s)
      end
      return source
    end
  end
end
