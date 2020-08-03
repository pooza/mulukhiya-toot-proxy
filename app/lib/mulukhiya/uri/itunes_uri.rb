module Mulukhiya
  class ItunesURI < Ginseng::URI
    def initialize(options = {})
      super
      @config = Config.instance
      @service = ItunesService.new
    end

    def itunes?
      return absolute? && @config['/itunes/hosts'].member?(host)
    end

    alias valid? itunes?

    def shortenable?
      return false unless itunes?
      return false unless album_id.present?
      @config['/itunes/patterns'].each do |entry|
        next unless path.match(entry['pattern'])
        return entry['shortenable']
      end
      return false
    end

    def shorten
      return self unless shortenable?
      dest = clone
      dest.host = @config['/itunes/hosts'].first
      dest.album_id = album_id
      dest.track_id = track_id
      dest.fragment = nil
      return dest
    end

    def album_id
      @config['/itunes/patterns'].each do |entry|
        next unless matches = path.match(entry['pattern'])
        return matches[1].to_i
      end
      return nil
    end

    def album_id=(id)
      self.path = "/#{@config['/itunes/country']}/album/#{id}"
    end

    def track_id
      return nil unless query_values['i']
      return query_values['i'].to_i
    rescue NoMethodError
      return nil
    end

    def track_id=(id)
      if id.present?
        values = query_values || {}
        values['i'] = id.to_i
      else
        values = nil
      end
      self.query_values = values
    end

    alias id track_id

    def track
      return nil unless itunes?
      return nil unless track_id.present?
      @track ||= @service.lookup(track_id)
      return @track
    end

    def album
      return nil unless itunes?
      return nil unless album_id.present?
      @album ||= @service.lookup(album_id)
      return @album
    end

    def image_uri
      return nil unless itunes?
      return nil if track_id.nil? && album_id.nil?
      unless @image_uri
        values = @service.lookup(track_id || album_id)
        @image_uri = Ginseng::URI.parse(values['artworkUrl100'].sub('100x100', pixel_size))
      end
      return @image_uri
    end

    alias image_url image_uri

    private

    def pixel_size
      pixel = @config['/handler/itunes_image/pixel']
      return "#{pixel}x#{pixel}"
    end
  end
end
