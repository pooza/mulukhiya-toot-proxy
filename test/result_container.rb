module Mulukhiya
  class ResultContainerTest < TestCase
    def setup
      @results = ResultContainer.new
      handler = Handler.create('itunes_url_nowplaying')
      handler.handle_pre_toot(status_field => "シュビドゥビ☆スイーツタイム\n#nowplaying https://itunes.apple.com/jp/album//1352845788?i=1352845804\n")[status_field]
      @results.push(handler.result)
    end

    def test_tags
      assert_kind_of(TagContainer, @results.tags)
    end

    def test_to_h
      assert_equal(@results.to_h, {'unknown' => {'itunes_url_nowplaying' => ['https://itunes.apple.com/jp/album//1352845788?i=1352845804']}})
    end

    def test_to_s
      assert_equal(@results.to_s, "---\nunknown:\n  itunes_url_nowplaying:\n  - https://itunes.apple.com/jp/album//1352845788?i=1352845804\n")
    end
  end
end
