module MulukhiyaTootProxy
  class URLHandler < Handler
    def exec(body, headers = {})
      @status = body['status']
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        next unless rewritable?(link)
        increment!
        rewrite(link)
      end
      return body
    end

    def rewrite(link)
      raise ImprementError, "#{__method__}が未実装です。"
    end

    def rewritable?(link)
      return true
    end
  end
end
