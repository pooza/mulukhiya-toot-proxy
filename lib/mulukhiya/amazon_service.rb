require 'amazon/ecs'
require 'addressable/uri'
require 'mulukhiya/config'

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
      response = Amazon::Ecs.item_lookup(asin, {country: 'jp', response_group: 'Images'})
      raise response.error if response.has_error?
      return Addressable::URI.parse(response.items.first.get('LargeImage/URL'))
    end
  end
end
