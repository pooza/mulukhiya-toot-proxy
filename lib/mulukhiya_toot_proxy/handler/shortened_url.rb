require 'addressable/uri'
require 'httparty'

module MulukhiyaTootProxy
  class ShortenedURLHandler < URLHandler
    def rewrite(link)
      uri = Addressable::URI.parse(link)
      while @config['/shortened_url/domains'].member?(uri.host)
        response = HTTParty.get(uri.normalize, {
          follow_redirects: false,
          timeout: @config['/shortened_url/timeout'],
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
      return @config['/shortened_url/domains'].member?(Addressable::URI.parse(link).host)
    end
  end
end
