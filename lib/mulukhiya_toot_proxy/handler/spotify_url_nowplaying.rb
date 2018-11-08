module MulukhiyaTootProxy
  class SpotifyUrlNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @service = SpotifyService.new
    end

    def updatable?(keyword)
      return false unless uri = SpotifyUri.parse(keyword)
      return false unless uri.spotify?
      return false unless uri.track.present?
      @tracks[keyword] = uri.track
      return true
    rescue
      return false
    end

    def update(keyword, status)
      return unless track = @tracks[keyword]
      status.push(track.name)
      track.artists.each do |artist|
        if @config['local']['nowplaying']['hashtag']
          artists = []
          SpotifyService.create_tags(artist.name).each do |tag|
            artists.push(tag)
          end
          status.push(artists.join(' '))
        else
          status.push(artist.name)
        end
      end
      return unless uri = @service.amazon_uri(track)
      status.push(uri.to_s)
      return unless uri = @service.itunes_uri(track)
      status.push(uri.to_s)
    end
  end
end
