require 'addressable/uri'
require 'mulukhiya/spotify'
require 'mulukhiya/handler'

module MulukhiyaTootProxy
  class SpotifyNowplayingHandler < Handler
    def exec(body, headers = {})
      lines = []
      updated = false
      body['status'].each_line do |line|
        lines.push(line)
        next if updated
        next unless matches = line.strip.match(/^#nowplaying\s(.*)$/i)
        keyword = matches[1]
        updated = true
        spotify = Spotify.new
        next unless track = spotify.search_track(keyword)
        lines.push(track.external_urls['spotify'])
      end
      body['status'] = lines.join("\n")
    end
  end
end
