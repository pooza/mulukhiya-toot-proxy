module Mulukhiya
  class MsnURITest < TestCase
    def setup
      @uris = {
        google: MsnURI.parse('https://www.google.co.jp'),
        msn: MsnURI.parse('https://www.msn.com'),
        news: MsnURI.parse('https://www.msn.com/ja-jp/news/entertainment/もうひとりの主人公-成長した姿に涙-最初は情けなかったのにカッコ良くなった漫画のサブキャラたち/ar-BB1oT7mx'),
      }
    end

    def test_msn?
      assert_false(@uris[:google].msn?)
      assert_predicate(@uris[:msn], :msn?)
      assert_predicate(@uris[:news], :msn?)
    end

    def test_shortenable?
      assert_false(@uris[:google].shortenable?)
      assert_false(@uris[:msn].shortenable?)
      assert_predicate(@uris[:news], :shortenable?)
    end

    def test_shorten
      assert_equal('https://www.google.co.jp', @uris[:google].shorten.to_s)
      assert_equal('https://www.msn.com', @uris[:msn].shorten.to_s)
      assert_equal('https://www.msn.com/ja-jp/news/entertainment/ar-BB1oT7mx', @uris[:news].shorten.to_s)
    end
  end
end
