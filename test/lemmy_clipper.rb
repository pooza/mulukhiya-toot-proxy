module Mulukhiya
  class LemmyClipperTest < TestCase
    def setup
      @lemmy = account.lemmy
    end

    def test_client
      assert_kind_of(Faye::WebSocket::Client, @lemmy.client)
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @lemmy.uri)
    end

    def test_clip
      @lemmy.clip(name: Time.now)
    end
  end
end
