require 'rack/test'
require 'json'

module MulukhiyaTootProxy
  class ServerTest < Test::Unit::TestCase
    include ::Rack::Test::Methods

    def setup
      @config = Config.instance
      @account = Mastodon.lookup_token_owner(@config['/test/token'])
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

    def test_toot_length
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

    def test_toot_zenkaku
      header 'Authorization', "Bearer #{@config['/test/token']}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => '！!！!！'}.to_json
      assert(JSON.parse(last_response.body)['content'].include?('<p>！!！!！<'))
    end

    def test_toot_response
      return if Handler.create('itunes_url_nowplaying').disable?
      header 'Authorization', "Bearer #{@config['/test/token']}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => '#nowplaying https://itunes.apple.com/jp/album//1447931442?i=1447931444&uo=4 #日本語のタグ', 'visibility' => 'private'}.to_json
      assert(last_response.ok?)
      tags = JSON.parse(last_response.body)['tags'].map{|v| v['name']}
      assert_equal(tags.count, 2)
      assert(tags.member?('日本語のタグ'))
      assert(tags.member?('nowplaying'))
    end

    def test_hook_toot
      Webhook.owned_all(@account['username']) do |hook|
        get hook.uri.path
        assert(last_response.ok?)

        header 'Content-Type', 'application/json'
        post hook.uri.path, {text: 'ひらめけ！ホーリーソード！'}.to_json
        assert(last_response.ok?)

        header 'Content-Type', 'application/json'
        post hook.uri.path, {text: '武田信玄', attachments: [{image_url: 'https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg'}]}.to_json
        assert(last_response.ok?)
      end
    end

    def test_app_auth
      get '/mulukhiya/app/auth'
      assert(last_response.ok?)

      post '/mulukhiya/app/auth', {code: 'hoge'}
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 400)
    end

    def test_style
      get '/mulukhiya/style/default'
      assert(last_response.ok?)

      get '/mulukhiya/style/undefined'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)
    end

    def test_static_resource
      get '/mulukhiya/icon.png'
      assert(last_response.ok?)
    end

    private

    def max_length
      length = @config['/mastodon/max_length']
      tags = TagContainer.default_tags
      if @config['/tagging/always_default_tags'] && tags.present?
        length = length - tags.join(' ').length - 1
      end
      return length
    end
  end
end
