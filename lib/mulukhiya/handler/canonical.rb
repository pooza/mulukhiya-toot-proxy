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
      body = Nokogiri::HTML.parse(HTTParty.get(link).body, nil, 'utf-8')
      element = body.xpath('//link[@rel="canonical"]')
      return false unless element.present?
      @canonical = element.first.attribute('href')
      return @canonical.present?
    end
  end
end
