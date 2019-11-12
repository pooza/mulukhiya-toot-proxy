require 'rack/test'

module MulukhiyaTootProxy
  class ServerTest < Test::Unit::TestCase
    include ::Rack::Test::Methods

    def setup
      @config = Config.instance
      return if Environment.ci?
      @account = Account.new(token: @config['/test/token'])
      @toot = @account.recent_toot
    end

    def app
      return Server
    end

    def test_about
      get '/about'
      assert(last_response.ok?)
      get '/mulukhiya/about'
      assert(last_response.ok?)
    end

    def test_health
      get '/mulukhiya/health'
      assert(last_response.ok?)
    end

    def test_not_found
      get '/not_found'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)
    end

    def test_search
      return if Environment.ci?

      header 'Authorization', "Bearer #{@account.token}"
      get '/api/v2/search?q=hoge'
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@account.token}"
      get '/api/v1/search?q=hoge'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)
    end

    def test_toot_length
      return if Environment.ci?

      header 'Authorization', "Bearer #{@account.token}"
      post '/api/v1/statuses', {'status' => 'A' * max_length}
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@account.token}"
      post '/api/v1/statuses', {'status' => 'A' * (max_length + 1)}
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)

      header 'Authorization', "Bearer #{@account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => 'B' * max_length}.to_json
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => 'B' * (max_length + 1)}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)
    end

    def test_toot_zenkaku
      return if Environment.ci?

      header 'Authorization', "Bearer #{@account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => '！!！!！'}.to_json
      assert(JSON.parse(last_response.body)['content'].include?('<p>！!！!！<'))
    end

    def test_toot_response
      return if Environment.ci?

      return if Handler.create('itunes_url_nowplaying').disable?
      header 'Authorization', "Bearer #{@account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {'status' => '#nowplaying https://itunes.apple.com/jp/album//1447931442?i=1447931444&uo=4 #日本語のタグ', 'visibility' => 'private'}.to_json
      assert(last_response.ok?)
      tags = JSON.parse(last_response.body)['tags'].map{|v| v['name']}
      assert_equal(tags.count, 2)
      assert(tags.member?('日本語のタグ'))
      assert(tags.member?('nowplaying'))
    end

    def test_hook_toot
      return if Environment.ci?

      header 'Content-Type', 'application/json'
      post '/mulukhiya/webhook', {text: 'ひらめけ！ホーリーソード！'}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      header 'Content-Type', 'application/json'
      post '/mulukhiya/webhook/0', {text: 'ひらめけ！ホーリーソード！'}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      hook = Webhook.owned_all(@account.username).to_a.first

      get hook.uri.path
      assert(last_response.ok?)

      header 'Content-Type', 'application/json'
      post hook.uri.path, {text: 'ひらめけ！ホーリーソード！'}.to_json
      assert(last_response.ok?)

      header 'Content-Type', 'application/json'
      post hook.uri.path, {text: '武田信玄', attachments: [{image_url: 'https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg'}]}.to_json
      assert(last_response.ok?)

      header 'Content-Type', 'application/json'
      post hook.uri.path, {}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)
    end

    def test_app_auth
      return if Environment.ci?

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
      length = length - tags.join(' ').length - 1 if tags.present?
      return length
    end
  end
end
