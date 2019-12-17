module MulukhiyaTootProxy
  class MastodonURITest < Test::Unit::TestCase
    def setup
      @uri = MastodonURI.parse('https://precure.ml/web/statuses/101118840135913675')
    end

    def test_toot_id
      assert_equal(@uri.toot_id, 101_118_840_135_913_675)
    end

    def test_service
      assert(@uri.service.is_a?(MastodonService))
    end

    def test_to_md
      assert_equal(@uri.to_md, "## アカウント\n[@ぷーざ@キュアスタ！ :sabacan:](https://precure.ml/@pooza)\n\n## 本文\n本店わかんなかったけどw とりあえず最寄りの満州で、昼間からビールです。\n\n## URL\nhttps://precure.ml/@pooza/101118840135913675\n")
    end
  end
end
