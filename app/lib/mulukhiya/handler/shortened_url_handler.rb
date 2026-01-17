module Mulukhiya
  class ShortenedURLHandler < URLHandler
    MAX_REDIRECTS = 8

    def rewrite(uri)
      source = Ginseng::URI.parse(uri.to_s)
      dest = resolve_redirects(source)
      @status = @status.sub(source.to_s, dest.to_s)
      return dest
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return uri
    end

    def rewritable?(uri)
      uri = Ginseng::URI.parse(uri.to_s) unless uri.is_a?(Ginseng::URI)
      return domains.member?(uri.host)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end

    def domains
      return handler_config(:domains) || []
    end

    private

    def resolve_redirects(source)
      dest = source.clone
      redirects = 0

      while redirects < MAX_REDIRECTS
        next_uri, status = fetch_redirect(dest)
        break unless next_uri
        break unless follow_redirect?(dest, next_uri, status)

        dest = next_uri
        redirects += 1
      end

      return dest
    end

    def fetch_redirect(dest)
      response = http.get(dest, {follow_redirects: false})
      location = response.headers['location']
      return [nil, nil] unless location

      next_uri = normalize_location(dest, location)
      return [nil, nil] unless next_uri&.host

      return [next_uri, response.status.to_i]
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: dest.to_s)
      return [nil, nil]
    end

    def follow_redirect?(current_uri, next_uri, status)
      return true if twitter?(current_uri)

      return true if permanent_redirect?(status)
      return false unless redirect_status?(status)
      return cross_domain?(current_uri, next_uri)
    end

    def twitter?(uri)
      return tco?(uri)
    end

    def tco?(uri)
      return uri.host.to_s.downcase == 't.co'
    end

    def permanent_redirect?(status)
      return status == 301 || status == 308
    end

    def redirect_status?(status)
      return (status / 100) == 3
    end

    def cross_domain?(current_uri, next_uri)
      return next_uri.host != current_uri.host
    end

    def normalize_location(base_uri, location)
      loc = location.to_s.strip
      return nil if loc.empty?

      return parse_scheme_relative(base_uri, loc) if scheme_relative?(loc)

      parsed = parse_absolute(loc)
      return parsed if parsed&.host

      return parse_absolute_path(base_uri, loc) if absolute_path?(loc)

      return parse_relative_path(base_uri, loc)
    end

    def scheme_relative?(loc)
      return loc.start_with?('//')
    end

    def absolute_path?(loc)
      return loc.start_with?('/')
    end

    def parse_scheme_relative(base_uri, loc)
      return Ginseng::URI.parse("#{base_uri.scheme}:#{loc}")
    end

    def parse_absolute(loc)
      return Ginseng::URI.parse(loc)
    rescue
      return nil
    end

    def parse_absolute_path(base_uri, loc)
      return Ginseng::URI.parse("#{base_uri.scheme}://#{base_uri.host}#{loc}")
    end

    def parse_relative_path(base_uri, loc)
      dir = normalize_dir(base_uri.path.to_s)
      url = "#{base_uri.scheme}://#{base_uri.host}#{dir}/#{loc}".squeeze('/').sub(':/', '://')
      return Ginseng::URI.parse(url)
    end

    def normalize_dir(path)
      dir = path.end_with?('/') ? path : File.dirname(path)
      return '/' if dir == '.'
      return dir
    end
  end
end
