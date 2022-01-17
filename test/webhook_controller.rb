module Mulukhiya
  class WebhookControllerTest < TestCase
    include ::Rack::Test::Methods

    def setup
      @parser = Environment.sns_class.new.create_parser
      @path_prefix_pattern = %r{^/mulukhiya/webhook}
    end

    def app
      return WebhookController
    end

    def test_not_found
      header 'Content-Type', 'application/json'
      post '/', {text: 'ひらめけ！ホーリーソード！'}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      header 'Content-Type', 'application/json'
      post '/0', {text: 'ひらめけ！ホーリーソード！'}.to_json
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)
    end

    def test_get
      return unless hook = test_account.webhook
      get hook.uri.path.sub(@path_prefix_pattern, '')
      assert(last_response.ok?)
    end

    def test_post
      return unless hook = test_account.webhook
      header 'Content-Type', 'application/json'
      post hook.uri.path.sub(@path_prefix_pattern, ''), {text: 'ひらめけ！ホーリーソード！'}.to_json
      assert(last_response.ok?)
    end

    def test_post_with_attachment
      return unless hook = test_account.webhook
      header 'Content-Type', 'application/json'
      post hook.uri.path.sub(@path_prefix_pattern, ''), {
        text: '武田信玄',
        attachments: [
          {image_url: 'https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg'},
          {image_url: 'https://images-na.ssl-images-amazon.com/images/I/21VK3xpmERL._AC_.jpg'},
        ],
      }.to_json
      assert(last_response.ok?)
    end

    def test_post_git_hub_payload
      return unless hook = test_account.webhook
      header 'Content-Type', 'application/json'
      header 'X-Github-Hook-Id', '武田信玄'
      post hook.uri.path.sub(@path_prefix_pattern, ''), {zen: '武田信玄'}.to_json
      assert(last_response.ok?)
      assert(last_response.body.include?('zen: 武田信玄'))
    end

    def test_invalid_request
      return unless hook = test_account.webhook
      header 'Content-Type', 'application/json'
      post hook.uri.path.sub(@path_prefix_pattern, ''), {}.to_json
      assert_false(last_response.ok?)
      assert([422, 502].member?(last_response.status))
    end
  end
end
