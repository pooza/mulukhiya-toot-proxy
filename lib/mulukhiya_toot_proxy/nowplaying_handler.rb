module MulukhiyaTootProxy
  class NowplayingHandler < Handler
    def exec(body, headers = {})
      status = []
      updated = false
      body['status'].each_line do |line|
        status.push(line.chomp)
        next if updated
        next unless matches = line.strip.match(/^#nowplaying\s+(.*)$/i)
        keyword = matches[1]
        next unless updatable?(keyword)
        update(keyword, status)
        updated = true
        increment!
      end
      body['status'] = status.join("\n")
      return body
    end

    def updatable?(keyword)
      raise ImplementError, "'#{__method__}' not implemented"
    end

    def update(keyword, status)
      raise ImplementError, "'#{__method__}' not implemented"
    end
  end
end
