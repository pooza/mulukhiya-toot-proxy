require 'amazon/ecs'
require 'nokogiri'
require 'addressable/uri'
require 'json'

module MulukhiyaTootProxy
  class AmazonService
    def initialize
      @config = Config.instance
      @http = HTTP.new
      return unless AmazonService.accesskey?
      Amazon::Ecs.configure do |options|
        options[:AWS_access_key_id] = @config['/amazon/access_key']
        options[:AWS_secret_key] = @config['/amazon/secret_key']
        options[:associate_tag] = AmazonService.associate_tag
      end
    end

    def create_image_uri(asin)
      return create_published_image_uri(asin) unless AmazonService.accesskey?
      cnt = 1
      response = Amazon::Ecs.item_lookup(asin, {
        country: @config['/amazon/country'],
        response_group: 'Images',
      })
      if response.has_error?
        raise Ginseng::RequestError, "ASIN '#{asin}' not found' (#{response.error})"
      end
      ['Large', 'Medium', 'Small'].each do |size|
        uri = AmazonURI.parse(response.items.first.get("#{size}Image/URL"))
        return uri if uri
      end
      return create_published_image_uri(asin)
    rescue Amazon::RequestError => e
      raise Ginseng::GatewayError, e.message if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def create_published_image_uri(asin)
      response = @http.get(create_item_uri(asin))
      html = Nokogiri::HTML.parse(response.to_s.force_encoding('utf-8'), nil, 'utf-8')
      ['landingImage', 'ebooksImgBlkFront', 'imgBlkFront'].each do |id|
        next unless elements = html.xpath(%{id("#{id}")})
        json = JSON.parse(elements.first.attribute('data-a-dynamic-image').value)
        next unless uri = Addressable::URI.parse(json.keys.first)
        return uri
      rescue
        next
      end
      return nil
    end

    def search(keyword, categories)
      return nil unless AmazonService.accesskey?
      cnt = 1
      categories.each do |category|
        response = Amazon::Ecs.item_search(keyword, {
          search_index: category,
          response_group: 'ItemAttributes',
          country: @config['/amazon/country'],
        })
        return response.items.first.get('ASIN') if response.items.present?
      end
      return nil
    rescue Amazon::RequestError => e
      raise Ginseng::GatewayError, e.message if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def create_item_uri(asin)
      uri = AmazonURI.parse(@config["/amazon/urls/#{@config['/amazon/country']}"])
      uri.asin = asin
      return uri
    end

    def self.associate_tag
      return Config.instance['/amazon/associate_tag']
    end

    def self.accesskey?
      config = Config.instance
      config['/amazon/access_key']
      config['/amazon/secret_key']
      return true
    rescue Ginseng::ConfigError
      return false
    end

    private

    def retry_limit
      return @config['/amazon/retry_limit']
    end
  end
end
