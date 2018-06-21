require 'addressable/uri'
require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class AmazonAsinHandler < Handler
    class URI < Addressable::URI
      def shortenable?
        return amazon? && asin
      end

      def amazon?
        return [
          'www.amazon.co.jp',
          'amazon.co.jp',
          'www.amazon.com',
          'amazon.com',
        ].member?(host)
      end

      def asin
        if matches = path.match(%r{/dp/([A-Za-z0-9]+)})
          return matches[1]
        end
        return nil
      end

      def short_uri
        dest = clone
        dest.path = "/dp/#{asin}"
        dest.query = nil
        dest.fragment = nil
        return dest
      end
    end

    def exec(source)
      ::URI.extract(source, ['http', 'https']).each do |link|
        uri = URI.parse(link)
        next unless uri.shortenable?
        increment!
        source.sub!(uri.to_s, uri.short_uri.to_s)
      end
      return source
    end
  end
end
