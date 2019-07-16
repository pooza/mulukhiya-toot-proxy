require 'nokogiri'

module MulukhiyaTootProxy
  class CanonicalHandler < URLHandler
    def initialize(params = {})
      super(params)
      @canonicals = {}
      @http = HTTP.new
    end

    def rewrite(link)
      raise Ginseng::NotFoundError, "Canonical for '#{link}' not found" unless @canonicals[link]
      @status.sub!(link, @canonicals[link])
      return @canonicals[link]
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
      @canonicals[link] = uri.to_s
      return true
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
