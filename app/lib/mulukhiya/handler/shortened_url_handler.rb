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
      return true if uri.host == 't.co'
      return domains.member?(uri.host)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end

    private

    def resolve_redirects(source)
      dest = source.clone
      redirects = 0
      while redirects < MAX_REDIRECTS
        next_uri, status = fetch_redirect(dest)
        break unless next_uri
        break unless (status / 100) == 3
        dest = next_uri
        redirects += 1
      end
      return dest
    end

    def fetch_redirect(src)
      response = http.get(src, {follow_redirects: false})
      return [nil, nil] unless location = response.headers['location']
      dest = normalize_location(src, location)
      return [nil, nil] unless dest&.host
      return [dest, response.code.to_i]
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: dest.to_s)
      return [nil, nil]
    end

    def domains
      return handler_config(:domains) || []
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
