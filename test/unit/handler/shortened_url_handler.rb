module Mulukhiya
  class ShortenedURLHandlerTest < TestCase
    def setup
      @handler = Handler.create(:shortened_url)
    end

    def test_handle_pre_toot
      @handler.handle_pre_toot(status_field => 'https://t.co/6Um3INeyU9')

      assert_equal({result: [{source_url: 'https://t.co/6Um3INeyU9', rewrited_url: 'https://www.youtube.com/watch?v=Ipsa3rgH1Cs&feature=youtu.be'}], errors: []}, @handler.debug_info)
    end

    def test_skip_non_whitelisted_url
      url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
      @handler.handle_pre_toot(status_field => url)

      # 非ホワイトリスト URL は rewritable? false でスキップされ result/errors とも空。
      # debug_info は両者空なら nil を返す契約（handler.rb）なので nil を検証する。
      assert_nil(@handler.debug_info)
    end
  end
end
