module Mulukhiya
  class TootURITest < TestCase
    def disable?
      return true unless Environment.toot?
      return super
    end

    def setup
      @uri = TootURI.parse('https://precure.ml/web/statuses/101118840135913675')
    end

    test 'テスト用投稿の有無' do
      assert_not_nil(account.recent_status)
    end

    def test_id
      assert_equal(101_118_840_135_913_675, @uri.id) if @uri
    end

    def test_service
      assert_kind_of(sns_class, @uri.service) if @uri
    end

    def test_to_md
      assert_equal("## アカウント\n[ぷーざ@キュアスタ！](https://precure.ml/@pooza)\n## 本文\n本店わかんなかったけどw とりあえず最寄りの満州で、昼間からビールです。\n## URL\nhttps://precure.ml/web/statuses/101118840135913675\n", @uri.to_md) if @uri
    end
  end
end
