module Mulukhiya
  class ServiceErrorTest < TestCase
    def setup
      WebMock.enable!
    end

    def test_mastodon_unauthorized
      service = MastodonService.new('https://mastodon.test', 'invalid_token')
      stub_request(:post, %r{mastodon\.test/api/v1/statuses})
        .to_return(status: 401, body: '{"error":"Unauthorized"}')

      error = assert_raises(Ginseng::GatewayError) do
        service.post('テスト')
      end

      assert_match(/401/, error.message)
    end

    def test_misskey_unauthorized
      service = MisskeyService.new('https://misskey.test', 'invalid_token')
      stub_request(:post, %r{misskey\.test/api/notes/create})
        .to_return(status: 401, body: '{"error":"Unauthorized"}')

      error = assert_raises(Ginseng::GatewayError) do
        service.post('テスト')
      end

      assert_match(/401/, error.message)
    end

    def test_mastodon_server_error
      service = MastodonService.new('https://mastodon.test', 'test_token')
      stub_request(:post, %r{mastodon\.test/api/v1/statuses})
        .to_return(status: 500, body: '{"error":"Internal Server Error"}')

      error = assert_raises(Ginseng::GatewayError) do
        service.post('テスト')
      end

      assert_match(/500/, error.message)
    end

    def test_mastodon_timeout
      service = MastodonService.new('https://mastodon.test', 'test_token')
      stub_request(:post, %r{mastodon\.test/api/v1/statuses})
        .to_timeout

      assert_raises(Ginseng::GatewayError) do
        service.post('テスト')
      end
    end

    def test_misskey_timeout
      service = MisskeyService.new('https://misskey.test', 'test_token')
      stub_request(:post, %r{misskey\.test/api/notes/create})
        .to_timeout

      assert_raises(Ginseng::GatewayError) do
        service.post('テスト')
      end
    end
  end
end
