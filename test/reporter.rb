module Mulukhiya
  class ReporterTest < TestCase
    def setup
      @reporter = Reporter.new
      handler = Handler.create('itunes_url_nowplaying')
      handler.handle_pre_toot(status_field => "シュビドゥビ☆スイーツタイム\n#nowplaying https://music.apple.com/jp/album//1352845788?i=1352845804\n")[status_field]
      @reporter.push(handler.summary)
    end

    def test_tags
      assert_kind_of(TagContainer, @reporter.tags)
    end

    def test_to_h
      assert_equal(@reporter.to_h, {
        'unknown' => {
          'itunes_url_nowplaying' => [{
            'url' => 'https://music.apple.com/jp/album//1352845788?i=1352845804',
            'title' => 'シュビドゥビ☆スイーツタイム',
            'artists' => ['宮本佳那子'],
          }],
        },
      })
    end

    def test_to_s
      assert_equal(@reporter.to_s, "---\nunknown:\n  itunes_url_nowplaying:\n  - url: https://music.apple.com/jp/album//1352845788?i=1352845804\n    title: シュビドゥビ☆スイーツタイム\n    artists:\n    - 宮本佳那子\n")
    end
  end
end
