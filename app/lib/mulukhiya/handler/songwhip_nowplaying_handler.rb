module Mulukhiya
  class SongwhipNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super
      @service = SongwhipService.new
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      @status.gsub!(/^#(nowplaying)[[:space:]]+(.*)$/i, '#\\1 \\2')
      return body if parser.command?
      @status.each_line do |line|
        push(line)
        if matches = line.strip.match(/^#nowplaying\s+(.*)$/i)
          @recent_keyword = matches[1]
        elsif reporter.temp[:track_uris].member?(line)
          @recent_keyword = line
        else
          next
        end
        update(@recent_keyword) if updatable?(@recent_keyword)
      end
      parser.text = body[status_field] = @lines.values.join("\n")
      return body
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, body: body)
    end

    def updatable?(keyword)
      return false unless uri = Ginseng::URI.parse(keyword)
      return false unless uri.absolute?
      @uris[keyword] = uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
      return false
    end

    def update(keyword)
      return unless uri = @uris[keyword]
      return unless songwhip_uri = @service.get(uri)
      push(songwhip_uri.to_s)
      result.push(source_url: uri.to_s, songwhip_url: songwhip_uri.to_s)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
    end
  end
end
