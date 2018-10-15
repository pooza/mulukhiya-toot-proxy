require 'mulukhiya/itunes_service'
require 'mulukhiya/uri/itunes'
require 'mulukhiya/amazon_service'
require 'mulukhiya/mastodon'
require 'mulukhiya/nowplaying_handler'

module MulukhiyaTootProxy
  class ItunesUrlNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @service = ItunesService.new
    end

    def updatable?(keyword)
      return false unless uri = ItunesURI.parse(keyword)
      return false unless uri.itunes?
      return false unless uri.track.present?
      @tracks[keyword] = uri.track
      return true
    rescue
      return false
    end

    def update(keyword, status)
      return unless track = @tracks[keyword]
      status.push(track['trackName'])
      status.push(Mastodon.create_tag(track['artistName']))
      return unless uri = @service.amazon_uri(track)
      status.push(uri.to_s)
      return unless uri = @service.spotify_uri(track)
      status.push(uri.to_s)
    end
  end
end
