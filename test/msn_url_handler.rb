module Mulukhiya
  class MsnURLHandlerTest < TestCase
    def setup
      @handler = Handler.create(:msn_url)
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.google.co.jp')

      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.msn.com/ja-jp/news/entertainment/もうひとりの主人公-成長した姿に涙-最初は情けなかったのにカッコ良くなった漫画のサブキャラたち/ar-BB1oT7mx')

      assert_equal({rewrited_url: 'https://www.msn.com/ja-jp/news/entertainment/ar-BB1oT7mx', source_url: 'https://www.msn.com/ja-jp/news/entertainment/もうひとりの主人公-成長した姿に涙-最初は情けなかったのにカッコ良くなった漫画のサブキャラたち/ar-BB1oT7mx'}, @handler.debug_info[:result].first)
    end
  end
end
