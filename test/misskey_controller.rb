module Mulukhiya
  class MisskeyControllerTest < TestCase
    include ::Rack::Test::Methods

    def disable?
      return true unless Environment.misskey?
      return super
    end

    def setup
      config['/handler/long_text_image/disable'] = true
      config['/handler/user_tag/disable'] = true
      @parser = parser_class.new
    end

    def app
      return MisskeyController
    end

    def test_note_length
      post '/api/notes/create', {status_field => 'A' * @parser.max_length, 'i' => test_token}

      assert_predicate(last_response, :ok?)

      post '/api/notes/create', {status_field => 'B' * (@parser.max_length + 1), 'i' => test_token}

      assert_false(last_response.ok?)
      assert_equal(400, last_response.status)

      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => 'C' * @parser.max_length, 'i' => test_token}.to_json

      assert_predicate(last_response, :ok?)

      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => 'D' * (@parser.max_length + 1), 'i' => test_token}.to_json

      assert_false(last_response.ok?)
      assert_equal(400, last_response.status)
    end

    def test_note_zenkaku
      header 'Content-Type', 'application/json'
      post '/api/notes/create', {status_field => '！!！!！', 'i' => test_token}.to_json

      assert_includes(JSON.parse(last_response.body).dig('createdNote', 'text'), '！!！!！')
    end

    def test_webhook_entries
      return unless webhook = app.webhook_entries&.first

      assert_kind_of(account_class, webhook[:account])
    end
  end
end
