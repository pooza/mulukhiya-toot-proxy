require 'addressable/uri'
require 'httparty'

module MulukhiyaTootProxy
  class ShortenedURLHandler < URLHandler
    def rewrite(link)
      uri = Addressable::URI.parse(link)
      while @config['/shortened_url/domains'].member?(uri.host)
        response = HTTParty.get(uri.normalize, {
          follow_redirects: false,
          headers: {'User-Agent' => Package.user_agent},
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
