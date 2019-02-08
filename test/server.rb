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

    def test_hook_toot
      Webhook.all do |hook|
        next unless hook.mastodon.account['username'] == @config['/test/account'].sub(/^@/, '')
        result = HTTParty.get(hook.uri)
        assert_equal(result.code, 200)

        result = HTTParty.post(hook.uri, {
          body: {text: 'ひらめけ！ホーリーソード！'}.to_json,
          headers: {'Content-Type' => 'application/json'},
        })
        assert_equal(result.code, 200)

        result = HTTParty.post(hook.uri, {
          body: {body: '武田信玄'}.to_json,
          headers: {'Content-Type' => 'application/json'},
        })
        assert_equal(result.code, 200)
      end
    end

    def test_not_found
      return unless hook = Webhook.all.first
      uri = hook.uri.clone
      uri.path = '/not_found'
      assert_equal(HTTParty.get(uri).code, 404)
    end

    private

    def toot_url
      url = Addressable::URI.parse(@config['/instance_url'])
      url.path = '/api/v1/statuses'
      return url
    end

    def headers
      return {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@config['/test/token']}",
        'User-Agent' => Package.user_agent,
      }
    end
  end
end
