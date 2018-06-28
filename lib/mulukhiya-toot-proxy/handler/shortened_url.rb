require 'addressable/uri'
require 'httparty'
require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class ShortenedUrlHandler < Handler
    def exec(body, headers = {})
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        uri = Addressable::URI.parse(link)
        next unless domains.member?(uri.host)
        increment!
        headers = HTTParty.get(link, {follow_redirects: false, timeout: timeout}).headers
        body['status'].sub!(link, headers['location']) if headers['location']
      end
      return body
    end

    private

    def timeout
      return (@config['application']['shortened_url']['timeout'] || 5)
    end

    def domains
      return @config['application']['shortened_url']['domains']
    end
  end
end
