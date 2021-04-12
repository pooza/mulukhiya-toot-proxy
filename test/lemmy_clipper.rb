module Mulukhiya
  class LemmyClipperTest < TestCase
    def test_client
      assert_kind_of(Faye::WebSocket::Client, account.lemmy.client)
    end

    def test_uri
      assert_kind_of(Ginseng::URI, account.lemmy.uri)
    end

    def test_clip
      account.lemmy.clip(name: Time.now)
    end
  end
end
