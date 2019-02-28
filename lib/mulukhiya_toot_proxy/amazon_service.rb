require 'amazon/ecs'
require 'nokogiri'
require 'addressable/uri'
require 'json'

module MulukhiyaTootProxy
  class AmazonService
    def initialize
      @config = Config.instance
      if AmazonService.accesskey?
        Amazon::Ecs.configure do |options|
          options[:AWS_access_key_id] = @config['/amazon/access_key']
          options[:AWS_secret_key] = @config['/amazon/secret_key']
          options[:associate_tag] = AmazonService.associate_tag
        end
      end
    end

    def image_uri(asin)
      return published_image_uri(asin) unless AmazonService.accesskey?
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
      return nil
    rescue Amazon::RequestError => e
      raise Ginseng::GatewayError, e.message if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def search(keyword, categories)
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

    def item_uri(asin)
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
    rescue
      return false
    end

    private

    def retry_limit
      return @config['/amazon/retry_limit']
    end
  end
end
