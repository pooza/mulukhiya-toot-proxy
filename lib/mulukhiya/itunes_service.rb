require 'httparty'
require 'mulukhiya/config'
require 'mulukhiya/package'
require 'mulukhiya/uri/itunes'
require 'mulukhiya/amazon_service'
require 'mulukhiya/spotify_service'
require 'mulukhiya/error/external_service'
require 'mulukhiya/error/request'
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
      response = JSON.parse(response.strip)
      raise RequestError, response['errorMessage'] if response['errorMessage']
      return nil unless response['results'].present?
      return response['results'].first
    rescue RequestError
      raise RequestError, "#{category} ’#{keyword}' が見つかりません。"
    rescue => e
      raise ExternalServiceError, e.message
    end

    def lookup(id)
      response = HTTParty.get(create_lookup_uri(id), {
        headers: {
          'User-Agent' => Package.user_agent,
        },
      })
      response = JSON.parse(response.strip)
      raise RequestError, response['errorMessage'] if response['errorMessage']
      return nil unless response['results'].present?
      return response['results'].first
    rescue RequestError
      raise RequestError, "ID '#{id}' が見つかりません。"
    rescue => e
      raise ExternalServiceError, e.message
    end

    def track_uri(track)
      return ItunesURI.parse(track['collectionViewUrl'])
    rescue
      return nil
    end

    def amazon_uri(track)
      keyword = [
        track['trackName'],
        track['artistName'],
      ].join(' ')
      amazon = AmazonService.new
      return nil unless asin = amazon.search(keyword, ['DigitalMusic', 'Music'])
      return amazon.item_uri(asin)
    end

    def spotify_uri(track)
      keyword = [
        track['trackName'],
        track['artistName'],
      ].join(' ')
      spotify = SpotifyService.new
      return nil unless track = spotify.search_track(keyword)
      return spotify.track_uri(track)
    end

    private

    def create_search_uri(keyword, category)
      uri = ItunesURI.parse(@config['application']['itunes']['urls']['search'])
      uri.query_values = {
        term: keyword,
        media: category,
        country: @config['local']['itunes']['country'],
        lang: @config['local']['itunes']['lang'],
      }
      return uri
    end

    def create_lookup_uri(id)
      uri = ItunesURI.parse(@config['application']['itunes']['urls']['lookup'])
      uri.query_values = {
        id: id,
        country: @config['local']['itunes']['country'],
        lang: @config['local']['itunes']['lang'],
      }
      return uri
    end
  end
end
