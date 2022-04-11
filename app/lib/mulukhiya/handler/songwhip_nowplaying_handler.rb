module Mulukhiya
  class SongwhipNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super
      @service = SongwhipService.new
    end

    def handle_line(line)
      if matches = line.strip.match(/^#nowplaying[[:blank:]]+(.*)$/i)
        @recent_keyword = matches[1]
      elsif reporter.temp[:track_uris].member?(line)
        @recent_keyword = line
      else
        return
      end
      return unless updatable?(@recent_keyword)
      update(@recent_keyword)
    end

    def updatable?(keyword)
      return false unless uri = Ginseng::URI.parse(keyword)
      return false unless uri.absolute?
      @uris[keyword] = uri
      return true
    rescue Addressable::URI::InvalidURIError
      return false
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword:)
      return false
    end

    def update(keyword)
      return unless uri = @uris[keyword]
      return unless songwhip_uri = @service.get(uri)
      push(songwhip_uri.to_s)
      result.push(source_url: uri.to_s, songwhip_url: songwhip_uri.to_s)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword:)
    end
  end
end
