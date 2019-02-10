require 'rack/test'

module MulukhiyaTootProxy
  class ServerTest < Test::Unit::TestCase
    include ::Rack::Test::Methods
    MAX_LENGTH = 500

    def setup
      @config = Config.instance
    end

    def app
      return Server
    end

    def test_about
      header 'User-Agent', Package.user_agent
      get '/about'
      assert(last_response.ok?)
      assert_equal(%{"#{Package.name} #{Package.version}"}, last_response.body)
    end

    def test_not_found
      header 'User-Agent', Package.user_agent
      get '/not_found'
      assert_false(last_response.ok?)
    end

    def test_webhook_get
      Webhook.all do |hook|
        header 'User-Agent', Package.user_agent
        get File.join('/mulukhiya/webhook', hook.digest)
        assert(last_response.ok?)
      end
    end

    def test_toot
      header 'Authorization', "Bearer #{@config['/test/token']}"
      header 'User-Agent', Package.user_agent
      post '/api/v1/statuses', {'status' => 'A' * MAX_LENGTH, 'visibility' => 'private'}
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@config['/test/token']}"
      header 'User-Agent', Package.user_agent
      post '/api/v1/statuses', {'status' => 'A' * (MAX_LENGTH + 1), 'visibility' => 'private'}
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)

      header 'Authorization', "Bearer #{@config['/test/token']}"
      header 'User-Agent', Package.user_agent
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => 'B' * MAX_LENGTH, 'visibility' => 'private'}.to_json
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@config['/test/token']}"
      header 'User-Agent', Package.user_agent
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => 'B' * (MAX_LENGTH + 1), 'visibility' => 'private'}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)
    end

    def test_hook_toot
      Webhook.all do |hook|
        next unless hook.mastodon.account['username'] == @config['/test/account'].sub(/^@/, '')

        header 'User-Agent', Package.user_agent
        get hook.uri.path
        assert(last_response.ok?)

        header 'User-Agent', Package.user_agent
        header 'Content-Type', 'application/json'
        post hook.uri.path, {text: 'ひらめけ！ホーリーソード！'}.to_json
        assert(last_response.ok?)

        header 'User-Agent', Package.user_agent
        header 'Content-Type', 'application/json'
        post hook.uri.path, {body: '武田信玄'}.to_json
        assert(last_response.ok?)
      end
    end
  end
end
