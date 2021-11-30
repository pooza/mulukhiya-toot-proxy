module Mulukhiya
  class SpotifyURI < Ginseng::URI
    include Package

    def initialize(options = {})
      super
      @spotify = SpotifyService.new
    end

    def spotify?
      return absolute? && host.split('.').member?('spotify')
    end

    alias valid? spotify?

    def track_id
      return nil unless SpotifyService.config?
      config['/spotify/patterns'].select {|v| v['type'] == 'track'}.each do |entry|
        next unless matches = path.match(entry['pattern'])
        return matches[1]
      end
      return nil
    end

    alias id track_id

    def track_id=(id)
      self.path = "/track/#{id}"
      self.fragment = nil
    end

    def album_id
      return nil unless SpotifyService.config?
      config['/spotify/patterns'].select {|v| v['type'] == 'album'}.each do |entry|
        next unless matches = path.match(entry['pattern'])
        return matches[1]
      end
      return nil
    end

    def album_id=(id)
      self.path = "/album/#{id}"
    end

    def album
      return nil unless spotify?
      return @spotify.lookup_album(album_id) if album_id
      return track&.album
    end

    def album?
      return album_id.present?
    end

    def album_name
      return album&.name
    end

    def track
      return nil unless spotify?
      return nil unless track_id.present?
      return @spotify.lookup_track(track_id)
    end

    def track?
      return track_id.present?
    end

    def track_name
      return track&.name
    end

    def title
      return track_name || album_name
    end

    def artists
      return (track || album).artists.map(&:name).to_set
    rescue
      return nil
    end

    def image_uri
      return nil unless spotify?
      return nil unless track_id
      @image_uri ||= @spotify.create_image_uri(@spotify.lookup_track(track_id))
      return @image_uri
    end
  end
end
