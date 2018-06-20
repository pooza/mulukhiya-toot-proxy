require 'addressable/uri'
require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class GooglHandler < Handler
    def exec(source)
      @result = 'goo.gl'
      URI.extract(source, ['http', 'https']).each do |link|
        uri = Addressable::URI.parse(link)
        next unless uri.host == 'goo.gl'




      end
      return source
    end
  end
end
