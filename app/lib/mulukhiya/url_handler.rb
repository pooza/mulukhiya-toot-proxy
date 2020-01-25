module Mulukhiya
  class URLHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field].to_s
      return body if parser.command?
      parser.uris do |uri|
        next unless rewritable?(uri)
        @result.push(source_url: uri.to_s, rewrited_url: rewrite(uri).to_s)
      end
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
