require 'addressable/uri'

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

    alias valid? spotify?

    def track_id
      @config['/spotify/patterns'].each do |entry|
        if matches = path.match(Regexp.new(entry['pattern']))
          return matches[1]
        end
      end
      return nil
    end

    alias id track_id

    def track_id=(id)
      self.path = "/track/#{id}"
    end

    def track
      return nil unless spotify?
      return nil unless track_id.present?
      return @spotify.lookup_track(track_id)
    end

    def image_uri
      return nil unless spotify?
      return nil unless track_id.present?
      @image_uri ||= @spotify.create_image_uri(@spotify.lookup_track(track_id))
      return @image_uri
    end

    alias image_url image_uri
  end
end
