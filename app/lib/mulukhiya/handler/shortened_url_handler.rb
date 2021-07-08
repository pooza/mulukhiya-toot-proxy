module Mulukhiya
  class ShortenedURLHandler < URLHandler
    def rewrite(uri)
      source = Ginseng::URI.parse(uri.to_s)
      dest = source.clone
      while domains.member?(dest.host)
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
      return domains.member?(uri.host)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end

    def domains
      return config['/handler/shortened_url/domains'] rescue []
    end
  end
end
