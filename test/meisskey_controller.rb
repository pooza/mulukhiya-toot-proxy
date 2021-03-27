module Mulukhiya
  class MeisskeyControllerTest < TestCase
    include ::Rack::Test::Methods

    def setup
      @parser = NoteParser.new
      @parser.account = account
      config['/handler/long_text_image/disable'] = true
    end

    def app
      return MeisskeyController
    end

    def test_note_length
      post '/api/notes/create', {status_field => 'A' * @parser.max_length, 'i' => test_token}
      assert(last_response.ok?)

      post '/api/notes/create', {status_field => 'B' * (@parser.max_length + 1), 'i' => test_token}
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 400)

      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => 'C' * @parser.max_length, 'i' => test_token}.to_json
      assert(last_response.ok?)

      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => 'D' * (@parser.max_length + 1), 'i' => test_token}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 400)
    end

    def test_note_zenkaku
      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => '！!！!！', 'i' => test_token}.to_json
      assert(JSON.parse(last_response.body)['createdNote']['text'].include?('！!！!！'))
    end

    def test_webhook_entries
      return unless webhook = app.webhook_entries&.first
      assert_kind_of(String, webhook[:digest])
      assert_kind_of(String, webhook[:token])
      assert_kind_of(account_class, webhook[:account])
    end
  end
end
