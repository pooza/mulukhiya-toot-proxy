require 'amazon/ecs'

module MulukhiyaTootProxy
  class AmazonService
    def initialize
      Config.validate('/local/amazon/access_key')
      Config.validate('/local/amazon/secret_key')
      Config.validate('/local/amazon/country')
      Config.validate('/local/amazon/associate_tag')
      @config = Config.instance
      Amazon::Ecs.configure do |options|
        options[:AWS_access_key_id] = @config['local']['amazon']['access_key']
        options[:AWS_secret_key] = @config['local']['amazon']['secret_key']
        options[:associate_tag] = AmazonService.associate_tag
      end
    end

    def image_uri(asin)
      cnt = 1
      response = Amazon::Ecs.item_lookup(asin, {
        country: @config['local']['amazon']['country'],
        response_group: 'Images',
      })
      raise RequestError, "ASIN '#{asin}' が見つかりません。 (#{response.error})" if response.has_error?
      ['Large', 'Medium', 'Small'].each do |size|
        uri = AmazonUri.parse(response.items.first.get("#{size}Image/URL"))
        return uri if uri
      end
      return nil
    rescue Amazon::RequestError => e
      raise ExternalServiceError, e.message if retry_limit < cnt
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
          country: @config['local']['amazon']['country'],
        })
        return response.items.first.get('ASIN') if response.items.present?
      end
      return nil
    rescue Amazon::RequestError => e
      raise ExternalServiceError, e.message if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def item_uri(asin)
      country = @config['local']['amazon']['country']
      uri = AmazonUri.parse(@config['application']['amazon']['urls'][country])
      uri.asin = asin
      return uri
    end

    def self.associate_tag
      tag = Config.instance['local']['amazon']['associate_tag']
      return nil unless tag.present?
      return tag
    rescue NoMethodError
      return nil
    end

    private

    def retry_limit
      return @config['application']['amazon']['retry_limit'] || 5
    end
  end
end
