require 'addressable/uri'
require 'httparty'
require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class ShortenedUrlHandler < Handler
    def exec(source)
      source.scan(%r{https?://[^\s]+}).each do |link|
        uri = Addressable::URI.parse(link)
        next unless domains.member?(uri.host)
        increment!
        headers = HTTParty.get(link, {follow_redirects: false}).headers
        source.sub!(link, headers['location']) if headers['location']
      end
      return source
    end

    private

    def domains
      return [
        't.co',
        'goo.gl',
        'bit.ly',
        'ow.ly',
      ]
    end
  end
end
