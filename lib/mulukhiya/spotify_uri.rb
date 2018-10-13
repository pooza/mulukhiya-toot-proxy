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

    def image_url
      return image_uri
    end

    def image_uri
      return nil unless spotify?
      return nil unless track_id.present?
      @image_uri ||= @spotify.image_uri(@spotify.lookup_track(track_id))
      return @image_uri
    end

    private

    def patterns
      return @config['application']['spotify']['patterns']
    end
  end
end
