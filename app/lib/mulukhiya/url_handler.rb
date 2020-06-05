module Mulukhiya
  class URLHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      parser.uris do |uri|
        next unless rewritable?(uri)
        rewrited = rewrite(uri)
        result.push(source_url: uri.to_s, rewrited_url: rewrited.to_s)
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      end
      parser.text = body[status_field]
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
