require 'nokogiri'

module Mulukhiya
  class CanonicalURLHandler < URLHandler
    def initialize(params = {})
      super(params)
      @canonicals = {}
      @http = HTTP.new
    end

    def rewrite(uri)
      source = Ginseng::URI.parse(uri.to_s)
      dest = @canonicals[source.to_s]
      raise Ginseng::NotFoundError, "Canonical for '#{source}' not found" unless dest
      @status.sub!(source.to_s, dest.to_s)
      return dest
    end

    private

    def rewritable?(uri)
      uri = Ginseng::URI.parse(uri.to_s) unless uri.is_a?(Ginseng::URI)
      return false unless uri.path.present?
      return false if uri.path == '/'
      return false if uri.query_values.present?
      response = @http.get(uri)
      body = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
      elements = body.xpath('//link[@rel="canonical"]')
      return false unless elements.present?
      canonical = Ginseng::URI.parse(elements.first.attribute('href'))
      return false unless canonical.absolute?
      return false if canonical.path == '/'
      @canonicals[uri.to_s] = canonical
      return true
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
