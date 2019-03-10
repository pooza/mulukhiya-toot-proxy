require 'rack/test'

module MulukhiyaTootProxy
  class ServerTest < Test::Unit::TestCase
    include ::Rack::Test::Methods

    def setup
      @config = Config.instance
    end

    def app
      return Server
    end

    def test_about
      get '/about'
      assert(last_response.ok?)
    end

    def test_not_found
      get '/not_found'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)
    end

    def test_toot
      header 'Authorization', "Bearer #{@config['/test/token']}"
      post '/api/v1/statuses', {'status' => 'A' * max_length, 'visibility' => 'private'}
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@config['/test/token']}"
      post '/api/v1/statuses', {'status' => 'A' * (max_length + 1), 'visibility' => 'private'}
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)

      header 'Authorization', "Bearer #{@config['/test/token']}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => 'B' * max_length, 'visibility' => 'private'}.to_json
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@config['/test/token']}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => 'B' * (max_length + 1), 'visibility' => 'private'}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)
    end

    def test_hook_toot
      account = Mastodon.lookup_token_owner(@config['/test/token'])
      assert(account.is_a?(Hash))
      Webhook.owned_all(account['username']) do |hook|
        get hook.uri.path
        assert(last_response.ok?)

        header 'Content-Type', 'application/json'
        post hook.uri.path, {text: 'ひらめけ！ホーリーソード！'}.to_json
        assert(last_response.ok?)

        header 'Content-Type', 'application/json'
        post hook.uri.path, {body: '武田信玄'}.to_json
        assert(last_response.ok?)
      end
    end

    private

    def max_length
      length = @config['/mastodon/max_length']
      tags = TagContainer.default_tags
      length = length - tags.join(' ').length - 1 if tags.present?
      return length
    end
  end
end
