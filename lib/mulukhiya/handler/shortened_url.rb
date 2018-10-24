require 'addressable/uri'
require 'httparty'
require 'mulukhiya/url_handler'
require 'mulukhiya/package'

module MulukhiyaTootProxy
  class ShortenedUrlHandler < UrlHandler
    def rewrite(link)
      uri = Addressable::URI.parse(link)
      while domains.member?(uri.host)
        response = HTTParty.get(uri.normalize, {
          follow_redirects: false,
          timeout: timeout,
          headers: {
            'User-Agent' => Package.user_agent,
          },
          ssl_ca_file: ENV['SSL_CERT_FILE'],
        })
        location = response.headers['location']
        break unless location
        uri = Addressable::URI.parse(location)
      end
      @status.sub!(link, uri.to_s)
    end

    private

    def rewritable?(link)
      return domains.member?(Addressable::URI.parse(link).host)
    end

    def timeout
      return @config['application']['shortened_url']['timeout']
    end

    def domains
      return @config['application']['shortened_url']['domains']
    end
  end
end
