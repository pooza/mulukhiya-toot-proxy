module Mulukhiya
  class TootURITest < TestCase
    def setup
      @uri = TootURI.parse('https://precure.ml/web/statuses/101118840135913675')
      @uri_mastodon = TootURI.parse('https://st.mstdn.b-shock.org/web/statuses/106057223567166956')
      @uri_pleroma = TootURI.parse('https://dev.ple.b-shock.org/notice/A6CON0Yxl9rrdutqlc')
    end

    def test_id
      assert_equal(@uri.id, 101_118_840_135_913_675)
    end

    def test_service
      assert_kind_of(sns_class, @uri.service)
    end

    def test_to_md
      assert_equal(@uri.to_md, "## アカウント\n[ぷーざ@キュアスタ！ :sabacan:](https://precure.ml/@pooza)\n## 本文\n本店わかんなかったけどw とりあえず最寄りの満州で、昼間からビールです。\n## URL\nhttps://precure.ml/web/statuses/101118840135913675\n")
    end

    def test_subject
      assert(@uri_mastodon.subject.start_with?('ネギトロ丼'))
      assert(@uri_pleroma.subject.start_with?('天ぷらそば'))
    end
  end
end
