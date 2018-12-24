module MulukhiyaTootProxy
  class URLHandler < Handler
    def exec(body, headers = {})
      @status = body['status']
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        next unless rewritable?(link)
        rewrite(link)
        increment!
      end
      return body
    end

    def rewrite(link)
      raise ImplementError, "'#{__method__}' not implemented"
    end

    def rewritable?(link)
      return true
    end
  end
end
