require 'digest/sha1'

module Mulukhiya
  class NowplayingHandler < Handler
    def initialize(params = {})
      super
      @uris = {}
      @tracks = {}
      @lines = {}
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body unless @status.match?(/#nowplaying\s/i)
      return body if parser.command?
      @status.gsub!(/^#(nowplaying)[[:space:]]+(.*)$/i, '#\\1 \\2')
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
      push("#{config['/nowplaying/track/prefix']} #{uri.track_name.escape_toot}") if uri.track?
      push("#{config['/nowplaying/album/prefix']} #{uri.album_name.escape_toot}") if uri.album_name
      push("#{config['/nowplaying/artist/prefix']} #{uri.artists.map(&:escape_toot).join(', ')}")
      tags.concat(uri.artists)
      result.push(url: uri.to_s, title: uri.title, artists: uri.artists)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
    end

    def verbose?
      return false
    end

    private

    def push(line)
      line.chomp!
      key = rand.to_s if line.empty?
      key ||= Digest::SHA1.hexdigest([line, @recent_keyword].to_json)
      @lines[key] = line
    end
  end
end
