require 'httparty'
require 'addressable/uri'
require 'mulukhiya/package'

module MulukhiyaTootProxy
  class Mastodon
    attr_reader :url
    attr_accessor :token

    def toot(body)
      return HTTParty.post(toot_url, {
        body: body.to_json,
        headers: headers,
      })
    end

    def url=(value)
      @url = Addressable::URI.parse(value)
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
        'Authorization' => "Bearer #{token}",
        'X-Mulukhiya' => '1',
      }
    end
  end
end
