require 'addressable/uri'
require 'nokogiri'

module MulukhiyaTootProxy
  class CanonicalHandler < URLHandler
    def initialize
      super
      @canonicals = {}
      @http = HTTP.new
    end

    def rewrite(link)
      @status.sub!(link, @canonicals[link]) if @canonicals[link].present?
    end

    private

    def rewritable?(link)
      uri = Addressable::URI.parse(link)
      return false unless uri.path.present?
      return false if uri.path == '/'
      return false if uri.query_values.present?
      response = @http.get(uri)
      body = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
      elements = body.xpath('//link[@rel="canonical"]')
      return false unless elements.present?
      uri = Addressable::URI.parse(elements.first.attribute('href'))
      @canonicals[link] = uri.to_s if uri.absolute?
      return @canonicals[link].present?
    end
  end
end
