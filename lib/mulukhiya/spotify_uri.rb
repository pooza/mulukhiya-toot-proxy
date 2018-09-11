require 'addressable/uri'
require 'mulukhiya/spotify_service'

module MulukhiyaTootProxy
  class SpotifyURI < Addressable::URI
    def initialize(options = {})
      super(options)
      @config = Config.instance
      @spotify = SpotifyService.new
    end

    def spotify?
      return absolute? && host.split('.').member?('spotify')
    end

    def track_id
      patterns.each do |entry|
        if matches = path.match(Regexp.new(entry['pattern']))
          return matches[1]
        end
      end
      return nil
    end

    def track_id=(id)
      self.path = "/track/#{id}"
    end

    def track
      return nil unless track_id.present?
      return @spotify.lookup_track(track_id)
    end

    private

    def patterns
      return @config['application']['spotify']['patterns']
    end
  end
end
