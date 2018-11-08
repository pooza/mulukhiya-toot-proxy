require 'rspotify'
require 'addressable/uri'

module MulukhiyaTootProxy
  class SpotifyService
    def initialize
      Config.validate('/local/spotify/client_id')
      Config.validate('/local/spotify/client_secret')
      @config = Config.instance
      ENV['ACCEPT_LANGUAGE'] ||= @config['local']['spotify']['language']
      RSpotify.authenticate(
        @config['local']['spotify']['client_id'],
        @config['local']['spotify']['client_secret'],
      )
    end

    def search_track(keyword)
      cnt = 1
      tracks = RSpotify::Track.search(keyword)
      return nil if tracks.nil?
      return tracks.first
    rescue RestClient::BadRequest
      raise RequestError, '曲が見つかりません。'
    rescue => e
      raise ExternalServiceError, "曲が見つかりません。 #{e.message}" if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def lookup_track(id)
      cnt = 1
      return RSpotify::Track.find(id)
    rescue RestClient::BadRequest
      raise RequestError, '曲が見つかりません。'
    rescue => e
      raise ExternalServiceError, "曲が見つかりません。 (#{e.message})" if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def lookup_artist(id)
      cnt = 1
      return RSpotify::Artist.find(id)
    rescue RestClient::BadRequest
      raise RequestError, 'アーティストが見つかりません。'
    rescue => e
      raise ExternalServiceError, "アーティストが見つかりません。 (#{e.message})" if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def track_uri(track)
      uri = SpotifyUri.parse(@config['application']['spotify']['urls']['track'])
      uri.track_id = track.id
      return nil unless uri.absolute?
      return uri
    end

    def image_uri(track)
      uri = Addressable::URI.parse(track.album.images.first['url'])
      return nil unless uri.absolute?
      return uri
    end

    def amazon_uri(track)
      amazon = AmazonService.new
      return nil unless asin = amazon.search(create_keyword(track), ['DigitalMusic', 'Music'])
      return amazon.item_uri(asin)
    end

    def itunes_uri(track)
      itunes = ItunesService.new
      return nil unless track = itunes.search(create_keyword(track), 'music')
      return itunes.track_uri(track)
    end

    def self.create_tags(artist)
      tags = []
      artist.sub!(/^(歌|語り):/, '')
      if matches = artist.match(/(.*)\(CV: ?(.*)\)/)
        tags.push(Mastodon.create_tag(matches[1]))
        tags.push("CV:#{Mastodon.create_tag(matches[2])}")
      elsif matches = artist.match(/(.*)\((.*)\)/)
        tags.push(Mastodon.create_tag(matches[1]))
        tags.push(Mastodon.create_tag(matches[2]))
      else
        tags.push(Mastodon.create_tag(artist))
      end
      return tags
    rescue
      return [names]
    end

    private

    def create_keyword(track)
      keyword = [track.name]
      track.artists.each do |artist|
        keyword.push(artist.name)
      end
      return keyword.join(' ')
    end

    def retry_limit
      return @config['application']['spotify']['retry_limit'] || 5
    end
  end
end
