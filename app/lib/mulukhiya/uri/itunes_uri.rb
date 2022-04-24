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

    alias valid? itunes?

    def shortenable?
      return false unless itunes?
      return false unless album_id
      return false unless entry = config['/itunes/patterns'].find {|v| path.match(v['pattern'])}
      return entry['shortenable']
    end

    def shorten
      return self unless shortenable?
      dest = clone
      dest.host = config['/itunes/hosts'].first
      dest.album_id = album_id
      dest.track_id = track_id
      return dest
    end

    def album_id
      config['/itunes/patterns'].each do |entry|
        next unless matches = path.match(entry['pattern'])
        return matches[1].to_i
      end
      return nil
    end

    def album_id=(id)
      self.path = "/#{config['/itunes/country']}/album/#{id}"
      self.fragment = nil
    end

    def album
      return nil unless itunes?
      return nil unless album_id
      @album ||= @service.lookup(album_id)
      return @album
    end

    def album?
      return album_id.present? && track_id.nil?
    end

    def album_name
      return album&.fetch('collectionName')
    end

    def track_id
      return nil unless query_values['i']
      return query_values['i'].to_i
    rescue NoMethodError
      return nil
    end

    alias id track_id

    def track?
      return album_id.present? && track_id.present?
    end

    def track_id=(id)
      values = query_values || {}
      values['i'] = id.to_i
      values.delete('i') if id.nil?
      values = nil unless values.present?
      self.query_values = values
      self.fragment = nil
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

    def title
      return track_name || album_name
    end

    def artists
      name = track['artistName'] if track
      name ||= album['artistName'] if album
      return nil if name.nil?
      names = ArtistParser.new(name).parse
      names = [name].to_set unless names.present?
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

    private

    def pixel_size
      return unless handler = Handler.create(:itunes_image)
      return "#{handler.pixel}x#{handler.pixel}"
    end
  end
end
