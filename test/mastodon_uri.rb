module MulukhiyaTootProxy
  class MastodonURITest < Test::Unit::TestCase
    def setup
      @uri = MastodonURI.parse('https://precure.ml/web/statuses/101118840135913675')
    end

    def test_toot_id
      assert_equal(@uri.toot_id, 101_118_840_135_913_675)
    end

    def test_service
      assert_true(@uri.service.is_a?(Mastodon))
    end
  end
end
