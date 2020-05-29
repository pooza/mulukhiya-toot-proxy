module Mulukhiya
  class URLHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      threads = []
      parser.uris do |uri|
        threads.push(Thread.new do
          result.push(source_url: uri.to_s, rewrited_url: rewrite(uri).to_s) if rewritable?(uri)
        end)
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      end
      threads.map(&:join)
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
