require 'amazon/ecs'
require 'addressable/uri'
require 'mulukhiya/config'
require 'mulukhiya/external_service_error'

module MulukhiyaTootProxy
  class AmazonService
    def initialize
      @config = Config.instance
      Amazon::Ecs.configure do |options|
        options[:AWS_access_key_id] = @config['local']['amazon']['access_key']
        options[:AWS_secret_key] = @config['local']['amazon']['secret_key']
        options[:associate_tag] = @config.associate_tag
      end
    end

    def image_url(asin)
      return image_uri(asin)
    end

    def image_uri(asin)
      cnt = 1
      response = Amazon::Ecs.item_lookup(asin, {country: 'jp', response_group: 'Images'})
      raise response.error if response.has_error?
      return Addressable::URI.parse(response.items.first.get('LargeImage/URL'))
    rescue Amazon::RequestError => e
      raise ExternalServiceError, e.message if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def retry_limit
      return @config['application']['amazon_ecs']['retry_limit']
    end
  end
end
