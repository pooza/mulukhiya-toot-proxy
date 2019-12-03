require 'nokogiri'

module MulukhiyaTootProxy
  class CanonicalURLHandler < URLHandler
    def initialize(params = {})
      super(params)
      @uris = {}
      @http = HTTP.new
    end

    def rewrite(link)
      raise Ginseng::NotFoundError, "Canonical for '#{link}' not found" unless @uris[link]
      @status.sub!(link, @uris[link].to_s)
      return @uris[link]
    end

    private

    def rewritable?(link)
      uri = Ginseng::URI.parse(link)
      return false unless uri.path.present?
      return false if uri.path == '/'
      return false if uri.query_values.present?
      response = @http.get(uri)
      body = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
      elements = body.xpath('//link[@rel="canonical"]')
      return false unless elements.present?
      uri = Ginseng::URI.parse(elements.first.attribute('href'))
      return false unless uri.absolute?
      return false if uri.path == '/'
      @uris[link] = uri
      return true
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
