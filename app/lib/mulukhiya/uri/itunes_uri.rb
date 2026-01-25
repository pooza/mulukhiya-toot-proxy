module Mulukhiya
  class ItunesURI < Ginseng::URI
    include Package

    def initialize(options = {})
      super
      @service = ItunesService.new
    end

    def itunes?
      return absolute? && config['/itunes/hosts'].member?(host)
    end

    def id
      return nil
    end

    def album_id
      return nil
    end

    def album
      return nil unless itunes?
      return nil unless album_id
      @album ||= @service.lookup(album_id)
      return @album
    end

    def album?
      return album_id.present?
    end

    def album_name
      return album&.fetch('collectionName')
    end

    def track_id
      return nil
    end

    def track?
      return track_id.present?
    end

    def track
      return nil unless itunes?
      return nil unless track_id
      @track ||= @service.lookup(track_id)
      return @track
    end

    def track_name
      return track&.fetch('trackName')
    end

    def song_id
      return nil
    end

    def song?
      return song_id.present?
    end

    def title
      return track_name || album_name
    end

    def artists
      name = track['artistName'] if track
      name ||= album['artistName'] if album
      return nil if name.nil?
      names = [name].to_set
      return names
    end

    def image_uri
      return nil unless itunes?
      return nil unless album_id
      unless @image_uri
        values = @service.lookup(track_id || album_id)
        @image_uri = Ginseng::URI.parse(values['artworkUrl100'].sub('100x100', pixel_size))
      end
      return @image_uri
    end

    def self.create(url)
      types.each do |type|
        uri = "Mulukhiya::Itunes#{type.to_s.capitalize}URI".constantize.parse(url)
        return uri if uri.valid?
      end
    end

    def self.types
      return [:track, :album, :song]
    end

    def self.pattern(type = :track)
      return Regexp.new(config["/itunes/patterns/#{type}"])
    end

    private

    def pixel_size
      return unless handler = Handler.create(:itunes_image)
      return "#{handler.pixel}x#{handler.pixel}"
    end
  end
end
