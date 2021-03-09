require 'zlib'

module Mulukhiya
  class NowplayingHandler < Handler
    def initialize(params = {})
      super
      @uris = {}
      @tracks = {}
      @lines = {}
      reporter.temp[:track_uris] ||= []
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      @status.gsub!(/^#(nowplaying)[[:space:]]+(.*)$/i, '#\\1 \\2')
      return body if parser.command?
      @status.each_line do |line|
        push(line)
        next unless matches = line.strip.match(/^#nowplaying\s+(.*)$/i)
        @recent_keyword = matches[1]
        update(@recent_keyword) if updatable?(@recent_keyword)
      end
      parser.text = body[status_field] = @lines.values.join("\n")
      return body
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, body: body)
    end

    def create_uri(keyword)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def updatable?(keyword)
      return false unless uri = create_uri(keyword)
      return false if uri.track.nil? && uri.album.nil?
      @uris[keyword] = uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
      return false
    end

    def update(keyword)
      return unless uri = @uris[keyword]
      push("#{track_prefix} #{uri.track_name.escape_toot}") if uri.track?
      push("#{album_prefix} #{uri.album_name.escape_toot}") if uri.album_name
      push("#{artist_prefix} #{uri.artists.map(&:escape_toot).join(', ')}")
      tags.concat(uri.artists)
      result.push(url: uri.to_s, title: uri.title, artists: uri.artists)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
    end

    def verbose?
      return false
    end

    private

    def track_prefix
      return config['/nowplaying/track/prefix']
    end

    def album_prefix
      return config['/nowplaying/album/prefix']
    end

    def artist_prefix
      return config['/nowplaying/artist/prefix']
    end

    def push(line)
      line.chomp!
      key = rand.to_s if line.empty?
      key ||= Zlib.adler32([line, @recent_keyword].join("\n"))
      @lines[key] = line
    end
  end
end
