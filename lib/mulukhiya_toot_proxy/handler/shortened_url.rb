module MulukhiyaTootProxy
  class ShortenedURLHandler < URLHandler
    def rewrite(link)
      uri = Ginseng::URI.parse(link)
      http = HTTP.new
      while @config['/shortened_url/domains'].member?(uri.host)
        response = http.get(uri, {follow_redirects: false})
        location = response.headers['location']
        break unless location
        uri = Ginseng::URI.parse(location)
      end
      @status.sub!(link, uri.to_s)
      return uri
    end

    private

    def rewritable?(link)
      return @config['/shortened_url/domains'].member?(Ginseng::URI.parse(link).host)
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
