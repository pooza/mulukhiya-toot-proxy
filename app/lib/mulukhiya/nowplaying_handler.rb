module Mulukhiya
  class NowplayingHandler < Handler
    def initialize(params = {})
      super
      @uris = {}
      @tracks = {}
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      @status.gsub!(/^#(nowplaying)[[:space:]]+(.*)$/i, '#\\1 \\2')
      @lines = []
      updated = false
      @status.each_line do |line|
        @lines.push(line.chomp)
        next if updated
        next unless matches = line.strip.match(/^#nowplaying\s+(.*)$/i)
        keyword = matches[1]
        next unless updatable?(keyword)
        update(keyword)
        updated = true
      end
      parser.text = body[status_field] = @lines.join("\n")
      return body
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
    end

    def updatable?(keyword)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def update(keyword)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def verbose?
      return false
    end

    private

    def push(line)
      lines = @status.each_line.to_a.map(&:chomp)
      @lines.push(line) unless lines.member?(line)
    end
  end
end
