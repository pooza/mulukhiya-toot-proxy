module Mulukhiya
  class HTTP < Ginseng::HTTP
    include Package
    attr_reader :base_uri

    def base_uri=(uri)
      unless uri.nil?
        uri = Ginseng::URI.parse(uri.to_s) unless uri.is_a?(Ginseng::URI)
        raise 'base_uri must be absolute' unless uri.absolute?
      end
      @base_uri = uri
    end

    def create_uri(uri)
      return uri if uri.is_a?(Ginseng::URI)
      uri = Ginseng::URI.parse(uri)
      return uri if uri.absolute?
      raise 'base_uri undefined' unless @base_uri
      uri.scheme = @base_uri.scheme
      uri.host = @base_uri.host
      uri.port = @base_uri.port
      return uri
    end

    def get(uri, options = {})
      return super(create_uri(uri), options)
    end

    def post(uri, options = {})
      return super(create_uri(uri), options)
    end

    def delete(uri, options = {})
      return super(create_uri(uri), options)
    end

    def upload(uri, file, headers = {}, body = {})
      return super(create_uri(uri), file, headers, body)
    end
  end
end
