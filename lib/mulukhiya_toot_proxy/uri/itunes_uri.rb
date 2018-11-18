require 'addressable/uri'

module MulukhiyaTootProxy
  class ItunesURI < Addressable::URI
    def initialize(options = {})
      super(options)
      @config = Config.instance
      @service = ItunesService.new
    end

    def itunes?
      return absolute? && host == 'itunes.apple.com'
    end

    def album_id
      patterns.each do |entry|
        if matches = path.match(Regexp.new(entry['pattern']))
          return matches[1]
        end
      end
      return nil
    end

    def track_id
      return query_values['i']
    rescue NoMethodError
      return nil
    end

    def track
      return nil unless track_id.present?
      return @service.lookup(track_id)
    end

    def image_uri
      return nil unless itunes?
      return nil unless track_id.present?
      track = @service.lookup(track_id)
      raise RequestError, "ID '#{track_id}' が見つかりません。" unless track
      unless @image_uri
        [160, 100, 60, 30].each do |size|
          @image_uri = Addressable::URI.parse(track["artworkUrl#{size}"])
          break if @image_uri
        end
      end
      return @image_uri
    end

    private

    def patterns
      return @config['/itunes/patterns']
    end
  end
end
