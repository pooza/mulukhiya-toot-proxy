require 'mulukhiya/spotify'
require 'mulukhiya/handler'

module MulukhiyaTootProxy
  class SpotifyMusicTrackHandler < Handler
    def exec(body, headers = {})
      spotify = Spotify.new
    end
  end
end
