module Mulukhiya
  class ShortenedURLHandler < URLHandler
    def rewrite(uri)
      source = Ginseng::URI.parse(uri.to_s)
      dest = source.clone
      http = HTTP.new
      while @config['/shortened_url/domains'].member?(dest.host)
        response = http.get(dest, {follow_redirects: false})
        break unless location = response.headers['location']
        dest = Ginseng::URI.parse(location)
      end
      @status.sub!(source.to_s, dest.to_s)
      return dest
    end

    private

    def rewritable?(uri)
      uri = Ginseng::URI.parse(uri.to_s) unless uri.is_a?(Ginseng::URI)
      return @config['/shortened_url/domains'].member?(uri.host)
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
