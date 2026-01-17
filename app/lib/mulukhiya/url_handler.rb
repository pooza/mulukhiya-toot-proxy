module Mulukhiya
  class URLHandler < Handler
    attr_reader :http

    def initialize(params = {})
      super
      @http = HTTP.new
    end

    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return if parser.command?
      rewritable_uris = parser.uris.select {|v| rewritable?(v)}
      Parallel.each(rewritable_uris, in_threads: Parallel.processor_count * 2) do |uri|
        rewrited = rewrite(uri)
        result.push(source_url: uri.to_s, rewrited_url: rewrited.to_s)
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      end
      parser.text = payload[text_field] = @status
    end

    def rewrite(uri)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def rewritable?(uri)
      return true
    end
  end
end
