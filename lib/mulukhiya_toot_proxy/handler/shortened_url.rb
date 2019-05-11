require 'addressable/uri'

module MulukhiyaTootProxy
  class ShortenedURLHandler < URLHandler
    def rewrite(link)
      uri = Addressable::URI.parse(link)
      http = HTTP.new
      while @config['/shortened_url/domains'].member?(uri.host)
        response = http.get(uri, {follow_redirects: false})
        location = response.headers['location']
        break unless location
        uri = Addressable::URI.parse(location)
      end
      @status.sub!(link, uri.to_s)
    end

    private

    def rewritable?(link)
      return @config['/shortened_url/domains'].member?(Addressable::URI.parse(link).host)
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
