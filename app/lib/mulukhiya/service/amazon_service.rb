require 'nokogiri'

module Mulukhiya
  class AmazonService
    def initialize
      @config = Config.instance
      @http = HTTP.new
      @logger = Logger.new
      @storage = AmazonItemStorage.new
      return unless AmazonService.config?
      @vacuum = Vacuum.new(
        marketplace: @config['/amazon/marketplace'],
        access_key: @config['/amazon/access_key'],
        secret_key: @config['/amazon/secret_key'],
        partner_tag: AmazonService.associate_tag,
      )
    end

    def create_image_uri(asin)
      if AmazonService.config?
        item = lookup(asin)
        ['Large', 'Medium', 'Small'].each do |size|
          uri = Ginseng::URI.parse(item.dig('Images', 'Primary', size, 'URL'))
          return uri if uri
        end
      else
        response = @http.get(create_item_uri(asin))
        body = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
        return nil unless element = body.xpath(%{//img[@data-old-hires!='']}).first
        return Ginseng::URI.parse(element['data-old-hires'])
      end
      return nil
    end

    def search(keyword, categories)
      return nil unless AmazonService.config?
      cnt ||= 0
      categories.each do |category|
        response = @vacuum.search_items(keywords: keyword, search_index: category)
        items = JSON.parse(response.to_s)['SearchResult']['Items']
        next unless items.present?
        return items.first['ASIN']
      end
      return nil
    rescue => e
      cnt += 1
      @logger.info(service: self.class.to_s, method: __method__, message: e.message, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(1)
      retry
    end

    def lookup(asin)
      cnt ||= 0
      unless item = @storage[asin]
        response = @vacuum.get_items(item_ids: [asin], resources: @config['/amazon/resources'])
        item = JSON.parse(response.to_s)['ItemsResult']['Items'].first
        @storage[asin] = item
      end
      return item
    rescue => e
      cnt += 1
      @logger.info(service: self.class.to_s, method: __method__, message: e.message, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(1)
      retry
    end

    def create_item_uri(asin)
      uri = AmazonURI.parse(@config["/amazon/urls/#{@config['/amazon/marketplace']}"])
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
      config['/amazon/marketplace']
      config['/amazon/access_key']
      config['/amazon/secret_key']
      config['/amazon/associate_tag']
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
