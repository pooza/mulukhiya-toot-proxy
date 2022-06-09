module Mulukhiya
  class AmazonService
    include Package

    def initialize
      @http = HTTP.new
      @storage = AmazonItemStorage.new
      return unless AmazonService.config?
      @vacuum = Vacuum.new(
        marketplace: config['/amazon/marketplace'],
        access_key: AmazonService.access_key,
        secret_key: AmazonService.secret_key,
        partner_tag: AmazonService.associate_tag,
      )
    end

    def create_image_uri(asin)
      return nil unless self.class.config?
      item = lookup(asin)
      ['Large', 'Medium', 'Small'].freeze.each do |size|
        next unless uri = Ginseng::URI.parse(item.dig('Images', 'Primary', size, 'URL'))
        next unless uri.absolute?
        return uri
      end
    rescue => e
      e.log
      return nil
    end

    def search(keyword, categories)
      return nil unless self.class.config?
      cnt ||= 0
      categories.each do |category|
        response = @vacuum.search_items(keywords: keyword, search_index: category)
        items = JSON.parse(response.to_s).dig('SearchResult', 'Items')
        next unless items.present?
        return items.first['ASIN']
      end
      return nil
    rescue => e
      cnt += 1
      e.log(count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(config['/amazon/retry/seconds'])
      retry
    end

    def lookup(asin)
      cnt ||= 0
      unless item = @storage[asin]
        response = @vacuum.get_items(item_ids: [asin], resources: config['/amazon/resources'])
        item = JSON.parse(response.to_s).dig('ItemsResult', 'Items').first
        @storage[asin] = item
      end
      return item
    rescue => e
      cnt += 1
      e.log(count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(config['/amazon/retry/seconds'])
      retry
    end

    def create_item_uri(asin)
      uri = AmazonURI.parse(config["/amazon/urls/#{config['/amazon/marketplace']}"])
      uri.asin = asin
      return uri
    end

    def self.associate_tag
      return config['/amazon/associate_tag'] rescue nil
    end

    def self.access_key
      return config['/amazon/access_key'] rescue nil
    end

    def self.secret_key
      return config['/amazon/secret_key'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/amazon/secret_key']
    end

    def self.config?
      return false unless access_key
      return false unless secret_key
      return false unless associate_tag
      config['/amazon/marketplace']
      return true
    rescue Ginseng::ConfigError
      return false
    end

    private

    def retry_limit
      return config['/http/retry/limit']
    end
  end
end
