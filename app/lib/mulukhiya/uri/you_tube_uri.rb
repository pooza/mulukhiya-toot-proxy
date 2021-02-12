module Mulukhiya
  class YouTubeURI < Ginseng::YouTube::URI
    include Package

    def album
      return nil
    end

    def album?
      return false
    end

    def album_name
      return nil
    end

    alias track data

    def track?
      return track.present?
    end

    alias track_name title

    def artists
      return ArtistParser.new(artist).parse if artist
      return nil
    end
  end
end
