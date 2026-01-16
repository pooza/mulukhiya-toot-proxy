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
      results = Concurrent::Array.new
      errs = Concurrent::Array.new
      Parallel.each(parser.uris.select {|v| rewritable?(v)}, in_threads: Parallel.processor_count * 2) do |uri|
        rewrited = rewrite(uri)
        results.push(source_url: uri.to_s, rewrited_url: rewrited.to_s)
      rescue => e
        errs.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      end
      results.each {|r| result.push(r)}
      errs.each {|e| errors.push(e)}
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
