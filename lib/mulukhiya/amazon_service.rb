require 'amazon/ecs'
require 'mulukhiya/config'
require 'mulukhiya/amazon_uri'
require 'mulukhiya/external_service_error'

module MulukhiyaTootProxy
  class AmazonService
    def initialize
      @config = Config.instance
      Amazon::Ecs.configure do |options|
        options[:AWS_access_key_id] = @config['local']['amazon']['access_key']
        options[:AWS_secret_key] = @config['local']['amazon']['secret_key']
        options[:associate_tag] = AmazonService.associate_tag
      end
    end

    def image_url(asin)
      return image_uri(asin)
    end

    def image_uri(asin)
      cnt = 1
      response = Amazon::Ecs.item_lookup(asin, {
        country: @config['application']['amazon']['country'],
        response_group: 'Images',
      })
      raise ExternalServiceError, response.error if response.has_error?
      return AmazonURI.parse(response.items.first.get('LargeImage/URL'))
    rescue Amazon::RequestError => e
      raise ExternalServiceError, e.message if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def search(keyword, categories = 'Books')
      cnt = 1
      response = Amazon::Ecs.item_search(keyword, {
        search_index: categories,
        response_group: 'ItemAttributes',
        country: @config['application']['amazon']['country'],
      })
      return nil unless response.items.present?
      return response.items.first.get('ASIN')
    rescue Amazon::RequestError => e
      raise ExternalServiceError, e.message if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def item_url(asin)
      return item_uri(asin)
    end

    def item_uri(asin)
      uri = AmazonURI.parse(@config['application']['amazon']['url'])
      uri.path = "/dp/#{asin}"
      return uri
    end

    def retry_limit
      return @config['application']['amazon']['retry_limit']
    end

    def self.associate_tag
      return Config.instance['local']['amazon']['associate_tag']
    rescue
      return nil
    end
  end
end
