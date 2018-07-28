require 'addressable/uri'
require 'httparty'
require 'nokogiri'
require 'mulukhiya/handler/url_handler'

module MulukhiyaTootProxy
  class CanonicalHandler < UrlHandler
    def rewrite(link)
      @status.sub!(link, @canonical)
    end

    private

    def rewritable?(link)
      uri = Addressable::URI.parse(link).normalize
      body = Nokogiri::HTML.parse(HTTParty.get(uri).body, nil, 'utf-8')
      elements = body.xpath('//link[@rel="canonical"]')
      return false unless elements.present?
      @canonical = elements.first.attribute('href')
      return @canonical.present?
    end
  end
end
