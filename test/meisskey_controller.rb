module Mulukhiya
  class MeisskeyControllerTest < TestCase
    include ::Rack::Test::Methods

    def setup
      @parser = NoteParser.new
      @parser.account = Environment.test_account
    end

    def app
      return MeisskeyController
    end

    def test_note_length
      post '/api/notes/create', {status_field => 'A' * @parser.max_length, 'i' => config['/agent/test/token']}
      assert(last_response.ok?)

      post '/api/notes/create', {status_field => 'B' * (@parser.max_length + 1), 'i' => config['/agent/test/token']}
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 400)

      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => 'C' * @parser.max_length, 'i' => config['/agent/test/token']}.to_json
      assert(last_response.ok?)

      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => 'D' * (@parser.max_length + 1), 'i' => config['/agent/test/token']}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 400)
    end

    def test_note_zenkaku
      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => '！!！!！', 'i' => config['/agent/test/token']}.to_json
      assert(JSON.parse(last_response.body)['createdNote']['text'].include?('！!！!！'))
    end

    def test_note_response
      return if Handler.create('itunes_url_nowplaying').disable?
      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => '#nowplaying https://music.apple.com/jp/album//1447931442?i=1447931444&uo=4 #日本語のタグ', 'i' => config['/agent/test/token']}.to_json
      assert(last_response.ok?)
      tags = JSON.parse(last_response.body)['createdNote']['tags']
      assert(tags.member?('日本語のタグ'))
      assert(tags.member?('nowplaying'))

      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => "ああああ\n\nいいい\n\n#nowplaying https://music.apple.com/jp/album/1447931442?i=1447931444&uo=4\n\n#nowplaying https://music.apple.com/jp/album/405905341?i=405905342&uo=4", 'i' => config['/agent/test/token']}.to_json
      assert(last_response.ok?)
      contents = JSON.parse(last_response.body)['createdNote']['text']
      assert(contents.start_with?('ああああ<br/><br/>いいい<br/><br/>'))
      assert(content.include?('唯一無二'))
      assert(content.include?('夢みる奇跡たち'))
    end

    def test_webhook_entries
      return unless webhook = app.webhook_entries&.first
      assert_kind_of(String, webhook[:digest])
      assert_kind_of(String, webhook[:token])
      assert_kind_of(Environment.account_class, webhook[:account])
    end
  end
end
