require 'addressable/uri'
require 'httparty'
require 'nokogiri'
require 'mulukhiya/handler/url_handler'

module MulukhiyaTootProxy
  class CanonicalHandler < UrlHandler
    def initialize
      super
      @canonicals = {}
    end

    def rewrite(link)
      @status.sub!(link, @canonicals[link]) if @canonicals[link].present?
    end

    private

    def rewritable?(link)
      uri = Addressable::URI.parse(link).normalize
      body = Nokogiri::HTML.parse(HTTParty.get(uri).body, nil, 'utf-8')
      elements = body.xpath('//link[@rel="canonical"]')
      return false unless elements.present?
      @canonicals[link] = elements.first.attribute('href')
      return @canonicals[link].present?
    end
  end
end
