module Mulukhiya
  # カスタムフィードの enclosure URL を channel の link で絶対化すること (#4549)。
  #
  # ⚠ RSS20FeedRendererTest 本体は DBMS 未設定の環境でケースごと omit される。
  # そこへ足すと「DB の無い手元では一度も走らない」ので、インスタンスを作らずに
  # 済むクラスメソッドとして切り出し、こちらで常に検査する。
  class FeedEnclosureURITest < TestCase
    BASE = 'https://dq-dai.com/news/'.freeze

    def resolve(value, base = BASE)
      return RSS20FeedRenderer.absolute_uri(value, base)
    end

    # ⚠ ここが本体。サイト相対の画像 URL を返すフィード (dqdai-anime) は、
    # これが無いと **サムネイルが全滅**したうえ 5 分おきに例外を吐き続ける。
    def test_resolves_site_relative_path
      assert_equal(
        'https://dq-dai.com/dai/img/news/thumb.webp',
        resolve('/dai/img/news/thumb.webp'),
      )
    end

    def test_resolves_document_relative_path
      assert_equal('https://dq-dai.com/news/thumb.webp', resolve('thumb.webp'))
    end

    # 絶対 URL は素通し（既存フィードの挙動を変えない）。
    def test_keeps_absolute_url
      url = 'https://www.dqdai-official.com/wp-content/uploads/2026/07/01-1-500x335.jpg'

      assert_equal(url, resolve(url))
    end

    def test_returns_nil_for_blank
      assert_nil(resolve(nil))
      assert_nil(resolve(''))
      assert_nil(resolve('   '))
    end

    # 基準が無ければ絶対化できない。**enclosure ごと落とす**のが正しい
    # （相対のまま載せると購読側が解決できない URL を掴む）。
    def test_returns_nil_without_base
      assert_nil(resolve('/dai/img/news/thumb.webp', nil))
      assert_nil(resolve('/dai/img/news/thumb.webp', ''))
    end

    # 基準が無くても絶対 URL は通る。
    def test_keeps_absolute_url_without_base
      assert_equal('https://example.jp/a.png', resolve('https://example.jp/a.png', nil))
    end

    # 解決に失敗する値で例外を投げない（フィード全体を落とさない）。
    def test_returns_nil_for_broken_value
      assert_nil(resolve("http://\n/broken"))
    end
  end
end
