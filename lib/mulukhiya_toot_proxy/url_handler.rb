module MulukhiyaTootProxy
  class URLHandler < Handler
    def hook_pre_toot(body, params = {})
      @status = body['status']
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        next unless rewritable?(link)
        rewrite(link)
        @result.push(link)
      end
      return body
    end

    def rewrite(link)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def rewritable?(link)
      return true
    end

    alias executable? rewritable?
  end
end
