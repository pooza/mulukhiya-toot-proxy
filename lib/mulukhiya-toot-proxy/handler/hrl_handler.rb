require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class UrlHandler < Handler
    def rewrite(link)
      raise 'rewriteが未定義です。'
    end

    def exec(body, headers = {})
      @status = body['status']
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        rewrite(link)
      end
      return body
    end
  end
end
