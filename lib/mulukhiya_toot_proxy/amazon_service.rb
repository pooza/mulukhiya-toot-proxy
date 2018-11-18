require 'amazon/ecs'

module MulukhiyaTootProxy
  class AmazonService
    def initialize
      @config = Config.instance
      Amazon::Ecs.configure do |options|
        options[:AWS_access_key_id] = @config['/amazon/access_key']
        options[:AWS_secret_key] = @config['/amazon/secret_key']
        options[:associate_tag] = AmazonService.associate_tag
      end
    end

    def image_uri(asin)
      cnt = 1
      response = Amazon::Ecs.item_lookup(asin, {
        country: @config['/amazon/country'],
        response_group: 'Images',
      })
      raise RequestError, "ASIN '#{asin}' が見つかりません。 (#{response.error})" if response.has_error?
      ['Large', 'Medium', 'Small'].each do |size|
        uri = AmazonURI.parse(response.items.first.get("#{size}Image/URL"))
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
          country: @config['/amazon/country'],
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
      country = @config['/amazon/country']
      uri = AmazonURI.parse(@config["/amazon/urls/#{country}"])
      uri.asin = asin
      return uri
    end

    def self.associate_tag
      tag = Config.instance['/amazon/associate_tag']
      return nil unless tag.present?
      return tag
    rescue NoMethodError
      return nil
    end

    private

    def retry_limit
      return @config['/amazon/retry_limit']
    end
  end
end
