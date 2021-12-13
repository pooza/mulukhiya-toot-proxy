module Mulukhiya
  class CanonicalURLHandler < URLHandler
    def initialize(params = {})
      super
      @canonicals = {}
    end

    def rewrite(uri)
      source = Ginseng::URI.parse(uri.to_s)
      dest = @canonicals[source.to_s]
      raise Ginseng::NotFoundError, 'Not Found' unless dest
      @status.sub!(source.to_s, dest.to_s)
      return dest
    end

    private

    def rewritable?(uri)
      uri = Ginseng::URI.parse(uri.to_s) unless uri.is_a?(Ginseng::URI)
      return false if ignore?(uri)
      response = http.get(uri, {
        headers: {'User-Agent' => handler_config(:useragent)},
      })
      return false unless element = response.body.nokogiri.xpath('//link[@rel="canonical"]').first
      return false unless canonical = Ginseng::URI.parse(element.attribute('href'))
      return false if ignore?(canonical)
      @canonicals[uri.to_s] = canonical
      return true
    rescue Ginseng::GatewayError
      return false
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end

    def ignore?(uri)
      return true unless uri.absolute?
      return true if uri.path == '/'
      return true if uri.path.empty?
      return true if uri.query_values.present?
      return true if handler_config('ignore/domains').any? {|domain| uri.host.end_with?(domain)}
      return true if AmazonURI.parse(uri.to_s).valid?
      return true if ItunesURI.parse(uri.to_s).valid?
      return false
    end
  end
end
