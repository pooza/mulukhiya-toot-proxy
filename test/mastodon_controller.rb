require 'rack/test'

module Mulukhiya
  class MastodonControllerTest < TestCase
    include ::Rack::Test::Methods

    def setup
      @config = Config.instance
      @parser = TootParser.new
      @parser.account = Environment.test_account
    end

    def app
      return MastodonController
    end

    def test_root
      get '/mulukhiya'
      assert(last_response.ok?)
    end

    def test_about
      get '/mulukhiya/about'
      assert(last_response.ok?)
    end

    def test_health
      get '/mulukhiya/health'
      assert(last_response.ok?)
    end

    def test_config
      get '/mulukhiya/config'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 403)

      header 'Authorization', 'Bearer invalid'
      get '/mulukhiya/config'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 403)

      header 'Authorization', "Bearer #{@parser.account.token}"
      get '/mulukhiya/config'
      assert(last_response.ok?)
    end

    def test_not_found
      get '/not_found'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)
    end

    def test_search
      header 'Authorization', "Bearer #{@parser.account.token}"
      get '/api/v2/search?q=hoge'
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@parser.account.token}"
      get '/api/v1/search?q=hoge'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)
    end

    def test_toot_length
      header 'Authorization', "Bearer #{@parser.account.token}"
      post '/api/v1/statuses', {status_field => 'A' * @parser.max_length}
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@parser.account.token}"
      post '/api/v1/statuses', {status_field => 'B' * (@parser.max_length + 1)}
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)

      header 'Authorization', "Bearer #{@parser.account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => 'C' * @parser.max_length}.to_json
      assert(last_response.ok?)

      header 'Authorization', "Bearer #{@parser.account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => 'D' * (@parser.max_length + 1)}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)
    end

    def test_toot_zenkaku
      header 'Authorization', "Bearer #{@parser.account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => '！!！!！'}.to_json
      assert(JSON.parse(last_response.body)['content'].include?('<p>！!！!！<'))
    end

    def test_programs
      get '/mulukhiya/programs'
      assert(last_response.ok?)
    rescue Ginseng::ConfigError
      @config['/programs/url'] = 'https://script.google.com/macros/s/AKfycbxlqRJxUq1dIsshRF6luZvL-_T08OTZD7YKOmAhLHfZeoZy3Ox-/exec'
      retry
    end

    def test_toot_response
      return if Handler.create('itunes_url_nowplaying').disable?
      header 'Authorization', "Bearer #{@parser.account.token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => '#nowplaying https://music.apple.com/jp/album//1447931442?i=1447931444&uo=4 #日本語のタグ', 'visibility' => 'private'}.to_json
      assert(last_response.ok?)
      tags = JSON.parse(last_response.body)['tags'].map {|v| v['name']}
      assert(tags.member?('日本語のタグ'))
      assert(tags.member?('nowplaying'))
    end

    def test_hook_toot
      header 'Content-Type', 'application/json'
      post '/mulukhiya/webhook', {text: 'ひらめけ！ホーリーソード！'}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      header 'Content-Type', 'application/json'
      post '/mulukhiya/webhook/0', {text: 'ひらめけ！ホーリーソード！'}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      return unless hook = @parser.account.webhook

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
      post '/mulukhiya/auth', {code: 'hoge'}
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

    def test_webhook_entries
      return unless webhook = app.webhook_entries&.first
      assert_kind_of(String, webhook[:digest])
      assert_kind_of(String, webhook[:token])
      assert_kind_of(Environment.account_class, webhook[:account])
    end
  end
end
