require 'rack/test'

module Mulukhiya
  class MisskeyControllerTest < TestCase
    include ::Rack::Test::Methods

    def setup
      @config = Config.instance
      @account = Environment.test_account
      @parser = NoteParser.new
    end

    def app
      return MisskeyController
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
      assert(last_response.ok?)
    end

    def test_not_found
      get '/not_found'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)
    end

    def test_note_length
      post '/api/notes/create', {status_field => 'A' * @parser.max_length, 'i' => @config['/agent/test/token']}
      assert(last_response.ok?)

      post '/api/notes/create', {status_field => 'A' * (@parser.max_length + 1), 'i' => @config['/agent/test/token']}
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 400)

      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => 'B' * @parser.max_length, 'i' => @config['/agent/test/token']}.to_json
      assert(last_response.ok?)

      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => 'B' * (@parser.max_length + 1), 'i' => @config['/agent/test/token']}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 400)
    end

    def test_toot_zenkaku
      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => '！!！!！', 'i' => @config['/agent/test/token']}.to_json
      assert(JSON.parse(last_response.body)['createdNote']['text'].include?('！!！!！'))
    end

    def test_toot_response
      return if Handler.create('itunes_url_nowplaying').disable?
      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => '#nowplaying https://music.apple.com/jp/album//1447931442?i=1447931444&uo=4 #日本語のタグ', 'i' => @config['/agent/test/token']}.to_json
      assert(last_response.ok?)
      tags = JSON.parse(last_response.body)['createdNote']['tags']
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

      return unless hook = @account.webhook

      get hook.uri.path
      assert(last_response.ok?)

      header 'Content-Type', 'application/json'
      post hook.uri.path, {text: 'ひらめけ！ホーリーソード！'}.to_json
      assert(last_response.ok?)

      header 'Content-Type', 'application/json'
      post hook.uri.path, {}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)
    end

    def test_app_auth
      get '/mulukhiya/auth', {token: 'hoge'}
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
  end
end
