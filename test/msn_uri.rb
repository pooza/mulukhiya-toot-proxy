module Mulukhiya
  class MsnURITest < TestCase
    def setup
      @uris = {
        google: MsnURI.parse('https://www.google.co.jp'),
        msn: MsnURI.parse('https://www.msn.com'),
        news1: MsnURI.parse('https://www.msn.com/ja-jp/news/entertainment/もうひとりの主人公-成長した姿に涙-最初は情けなかったのにカッコ良くなった漫画のサブキャラたち/ar-BB1oT7mx'),
        news2: MsnURI.parse('https://www.msn.com/ja-jp/entertainment/entertainmentnews/わんだふるぷりきゅあ-ざ-むーびー-大冒険のはじまり-予感させる新スチールが公開に/ar-BB1pfNnZ'),
      }
    end

    def test_msn?
      assert_false(@uris[:google].msn?)
      assert_predicate(@uris[:msn], :msn?)
      assert_predicate(@uris[:news1], :msn?)
      assert_predicate(@uris[:news2], :msn?)
    end

    def test_shortenable?
      assert_false(@uris[:google].shortenable?)
      assert_false(@uris[:msn].shortenable?)
      assert_predicate(@uris[:news1], :shortenable?)
      assert_predicate(@uris[:news2], :shortenable?)
    end

    def test_shorten
      assert_equal('https://www.google.co.jp', @uris[:google].shorten.to_s)
      assert_equal('https://www.msn.com', @uris[:msn].shorten.to_s)
      assert_equal('https://www.msn.com/ja-jp/news/entertainment/ar-BB1oT7mx', @uris[:news1].shorten.to_s)
      assert_equal('https://www.msn.com/ja-jp/entertainment/entertainmentnews/ar-BB1pfNnZ', @uris[:news2].shorten.to_s)
    end
  end
end
