module Mulukhiya
  class LemmyClipperTest < TestCase
    def setup
      @clipper = LemmyClipper.new(
        host: config['/lemmy/test/host'],
        user_id: config['/lemmy/test/user_id'],
        password: config['/lemmy/test/password'].decrypt,
        community_id: config['/lemmy/test/community_id'],
      )
    end

    def test_client
      assert_kind_of(Faye::WebSocket::Client, @clipper.client)
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @clipper.uri)
    end

    def test_clip
      @clipper.clip(name: Time.now)
    end
  end
end
