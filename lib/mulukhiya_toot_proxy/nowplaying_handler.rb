module MulukhiyaTootProxy
  class NowplayingHandler < Handler
    def exec(body, headers = {})
      @source_status = body['status'].clone
      @status = []
      updated = false
      @source_status.each_line do |line|
        @status.push(line.chomp)
        next if updated
        next unless matches = line.strip.match(/^#nowplaying\s+(.*)$/i)
        keyword = matches[1]
        next unless updatable?(keyword)
        update(keyword)
        updated = true
        @result.push(keyword)
      end
      body['status'] = @status.join("\n")
      return body
    end

    def updatable?(keyword)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias executable? updatable?

    def update(keyword)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    private

    def push(line)
      @status.push(line) unless @source_status.include?(line)
    end
  end
end
