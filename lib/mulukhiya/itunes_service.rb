require 'addressable/uri'
require 'httparty'
require 'mulukhiya/config'
require 'mulukhiya/package'
require 'mulukhiya/external_service_error'
require 'json'

module MulukhiyaTootProxy
  class ItunesService
    def initialize
      @config = Config.instance
    end

    def search(keyword, category)
      response = HTTParty.get(create_search_uri(keyword, category), {
        headers: {
          'User-Agent' => Package.user_agent,
        },
      })
      response = JSON.parse(response.strip.to_s)
      return unless response['results'].present?
      return response['results'].first
    rescue => e
      raise ExternalServiceError, e.message
    end

    private

    def create_search_uri(keyword, category)
      uri = Addressable::URI.parse(@config['application']['itunes']['urls']['search'])
      uri.query_values = {
        term: keyword,
        media: category,
        country: @config['application']['itunes']['country'],
        lang: @config['application']['itunes']['lang'],
      }
      return uri
    end
  end
end
