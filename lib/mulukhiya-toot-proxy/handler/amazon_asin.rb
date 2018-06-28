require 'mulukhiya-toot-proxy/amazon_uri'
require 'mulukhiya-toot-proxy/handler'

module MulukhiyaTootProxy
  class AmazonAsinHandler < Handler
    def exec(body, headers = {})
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        uri = AmazonURI.parse(link)
        uri.associate_id = associate_id
        next unless uri.shortenable?
        increment!
        body['status'].sub!(link, uri.shorten.to_s)
      end
      return body
    end

    private

    def associate_id
      return @config['local']['amazon']['associate_id']
    rescue
      return nil
    end
  end
end
