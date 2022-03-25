module Mulukhiya
  class LemmyClipperTest < TestCase
    def setup
      @lemmy = account.lemmy
    end

    def test_client
      assert_kind_of(Faye::WebSocket::Client, @lemmy.client)
    end

    def test_verify_peer?
      assert_boolean(@lemmy.verify_peer?)
    end

    def test_root_cert_file
      assert_path_exists(@lemmy.root_cert_file)
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @lemmy.uri)
    end

    def test_clip
      @lemmy.clip(name: Time.now)
    end

    def test_communities
      assert_kind_of(Hash, @lemmy.communities)
    end
  end
end
