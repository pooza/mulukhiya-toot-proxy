require 'amazon/ecs'
require 'nokogiri'

module Mulukhiya
  class AmazonService
    def initialize
      @config = Config.instance
      @http = HTTP.new
      @logger = Logger.new
      return unless AmazonService.config?
      Amazon::Ecs.configure do |options|
        options[:AWS_access_key_id] = @config['/amazon/access_key']
        options[:AWS_secret_key] = @config['/amazon/secret_key']
        options[:associate_tag] = AmazonService.associate_tag
      end
    end

    def create_image_uri(asin)
      item = lookup(asin)
      ['Large', 'Medium', 'Small'].each do |size|
        uri = AmazonURI.parse(item.get("#{size}Image/URL"))
        return uri if uri
      end
    end

    def search(keyword, categories)
      return nil unless AmazonService.config?
      cnt ||= 0
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
      @logger.info(e)
      raise Ginseng::GatewayError, e.message, e.backtrace if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def lookup(asin)
      cnt ||= 0
      response = Amazon::Ecs.item_lookup(asin, {
        country: @config['/amazon/country'],
        response_group: 'Images,ItemAttributes',
      })
      if response.has_error?
        raise Ginseng::RequestError, "ASIN '#{asin}' not found' (#{response.error})"
      end
      return response.items&.first
    rescue Amazon::RequestError => e
      @logger.info(e)
      raise Ginseng::GatewayError, e.message, e.backtrace if retry_limit < cnt
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
    rescue Ginseng::ConfigError
      return nil
    end

    def self.config?
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
