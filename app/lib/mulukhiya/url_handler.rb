module Mulukhiya
  class URLHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      parser.uris do |uri|
        next unless rewritable?(uri)
        @result.push(source_url: uri.to_s, rewrited_url: rewrite(uri).to_s)
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.merge(url: uri.to_s))
      end
      parser.body = body[status_field]
      return body
    end

    def rewrite(uri)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def rewritable?(uri)
      return true
    end
  end
end
