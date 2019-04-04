require 'json'

module MulukhiyaTootProxy
  class ItunesService
    def initialize
      @config = Config.instance
      @http = HTTP.new
    end

    def search(keyword, category)
      response = @http.get(create_search_uri(keyword, category))
      response = JSON.parse(response.strip)
      raise Ginseng::RequestError, response['errorMessage'] if response['errorMessage']
      return nil unless response['results'].present?
      return response['results'].first
    rescue Ginseng::RequestError => ex
      raise Ginseng::RequestError, "#{category} ’#{keyword}' not found (#{ex.message})"
    rescue => ex
      raise Ginseng::GatewayError, ex.message
    end

    def lookup(id)
      response = @http.get(create_lookup_uri(id))
      response = JSON.parse(response.strip)
      raise Ginseng::RequestError, response['errorMessage'] if response['errorMessage']
      return nil unless response['results'].present?
      return response['results'].first
    rescue Ginseng::RequestError => ex
      raise Ginseng::RequestError, "'#{id}' not found (#{ex.message})"
    rescue => ex
      raise Ginseng::GatewayError, ex.message
    end

    def track_uri(track)
      uri = ItunesURI.parse(track['collectionViewUrl'])
      return nil unless uri.absolute?
      return uri
    end

    def amazon_uri(track)
      amazon = AmazonService.new
      return nil unless asin = amazon.search(create_keyword(track), ['DigitalMusic', 'Music'])
      return amazon.item_uri(asin)
    end

    def spotify_uri(track)
      spotify = SpotifyService.new
      return nil unless track = spotify.search_track(create_keyword(track))
      return spotify.track_uri(track)
    end

    private

    def create_keyword(track)
      return [track['trackName'], track['artistName']].join(' ')
    end

    def create_search_uri(keyword, category)
      uri = ItunesURI.parse(@config['/itunes/urls/search'])
      uri.query_values = {
        term: keyword,
        media: category,
        country: @config['/itunes/country'],
        lang: @config['/itunes/lang'],
      }
      return uri
    end

    def create_lookup_uri(id)
      uri = ItunesURI.parse(@config['/itunes/urls/lookup'])
      uri.query_values = {
        id: id,
        country: @config['/itunes/country'],
        lang: @config['/itunes/lang'],
      }
      return uri
    end
  end
end
