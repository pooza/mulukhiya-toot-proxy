module Mulukhiya
  class MastodonControllerTest < TestCase
    include ::Rack::Test::Methods

    def setup
      @parser = parser_class.new
      config['/handler/long_text_image/disable'] = true
    end

    def app
      return MastodonController
    end

    def test_search
      header 'Authorization', "Bearer #{test_token}"
      get '/api/v2/search?q=hoge'
      assert_predicate(last_response, :ok?)

      header 'Authorization', "Bearer #{test_token}"
      get '/api/v1/search?q=hoge'
      assert_false(last_response.ok?)
      assert_equal(404, last_response.status)
    end

    def test_toot_length
      header 'Authorization', "Bearer #{test_token}"
      post '/api/v1/statuses', {status_field => 'A' * @parser.max_length}
      assert_predicate(last_response, :ok?)

      header 'Authorization', "Bearer #{test_token}"
      post '/api/v1/statuses', {status_field => 'B' * (@parser.max_length + 1)}
      assert_false(last_response.ok?)
      assert_equal(422, last_response.status)

      header 'Authorization', "Bearer #{test_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => 'C' * @parser.max_length}.to_json
      assert_predicate(last_response, :ok?)

      header 'Authorization', "Bearer #{test_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => 'D' * (@parser.max_length + 1)}.to_json
      assert_false(last_response.ok?)
      assert_equal(422, last_response.status)
    end

    def test_toot_zenkaku
      header 'Authorization', "Bearer #{test_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/statuses', {status_field => '！!！!！'}.to_json
      assert_includes(JSON.parse(last_response.body)['content'], '<p>！!！!！<')
    end

    def test_webhook_entries
      return unless webhook = app.webhook_entries&.first
      assert_kind_of(account_class, webhook[:account])
    end
  end
end
