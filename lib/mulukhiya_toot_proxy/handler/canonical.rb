require 'addressable/uri'
require 'httparty'
require 'nokogiri'

module MulukhiyaTootProxy
  class CanonicalHandler < URLHandler
    def initialize
      super
      @canonicals = {}
    end

    def rewrite(link)
      @status.sub!(link, @canonicals[link]) if @canonicals[link].present?
    end

    private

    def rewritable?(link)
      uri = Addressable::URI.parse(link)
      return false if uri.query_values.present?
      response = HTTParty.get(uri.normalize, {
        headers: {'User-Agent' => Package.user_agent},
      })
      body = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
      elements = body.xpath('//link[@rel="canonical"]')
      return false unless elements.present?
      uri = Addressable::URI.parse(elements.first.attribute('href'))
      @canonicals[link] = uri.to_s if uri.absolute?
      return @canonicals[link].present?
    end
  end
end
