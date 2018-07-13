require 'httparty'
require 'addressable/uri'
require 'mulukhiya/package'

module MulukhiyaTootProxy
  class Mastodon
    def initialize(url, token)
      @url = Addressable::URI.parse(url)
      @token = token
    end

    def toot(body)
      return HTTParty.post(toot_url, {
        body: body.to_json,
        headers: headers,
      })
    end

    private

    def toot_url
      toot_url = @url.clone
      toot_url.path = '/api/v1/statuses'
      return toot_url
    end

    def headers
      return {
        'Content-Type' => 'application/json',
        'User-Agent' => Package.user_agent,
        'Authorization' => "Bearer #{@token}",
        'X-Mulukhiya' => '1',
      }
    end
  end
end
