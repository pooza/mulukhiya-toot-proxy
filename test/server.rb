require 'mulukhiya/config'
require 'mulukhiya/package'
require 'addressable/uri'
require 'httparty'

module MulukhiyaTootProxy
  class ServerTest < Test::Unit::TestCase
    MAX_LENGTH = 500

    def setup
      @config = Config.instance
    end

    def test_toot
      result = HTTParty.post(toot_url, {
        body: {status: 'a' * MAX_LENGTH, visibility: 'private'}.to_json,
        headers: headers,
      })
      assert_equal(200, result.code)

      result = HTTParty.post(toot_url, {
        body: {status: 'a' * (MAX_LENGTH + 1), visibility: 'private'}.to_json,
        headers: headers,
      })
      assert_equal(422, result.code) # 文字数オーバー
    end

    private

    def toot_url
      url = Addressable::URI.parse(@config['local']['instance_url'])
      url.path = '/api/v1/statuses'
      return url
    end

    def headers
      return {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@config['local']['test']['token']}",
        'User-Agent' => Package.user_agent,
      }
    end
  end
end
