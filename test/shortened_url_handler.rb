module Mulukhiya
  class ShortenedURLHandlerTest < TestCase
    def setup
      @handler = Handler.create(:shortened_url)
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.google.co.jp/?q=日本語')

      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://4sq.com/2NYeZb6')

      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'キュアスタ！ https://goo.gl/uJJKpV')

      assert_equal(1, @handler.debug_info[:result].count)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://bit.ly/2Lquwnt')

      assert_equal(1, @handler.debug_info[:result].count)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://goo.gl/uJJKpV https://bit.ly/2MeJHvW')

      assert_equal(2, @handler.debug_info[:result].count)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://spotify.link/BgfsBAMTbzb')

      assert_equal(1, @handler.debug_info[:result].count)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://spotify.app.link/BgfsBAMTbzb?_p=c2153fdc9c077af1ea1990ffecb6')

      assert_equal(1, @handler.debug_info[:result].count)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://news.google.com/rss/articles/CBMiMWh0dHBzOi8vd3d3Lml3YXRlLW5wLmNvLmpwL2FydGljbGUvb3JpY29uLzIyODQ3ODbSATVodHRwczovL3d3dy5pd2F0ZS1ucC5jby5qcC9hcnRpY2xlL29yaWNvbi8yMjg0Nzg2L2FtcA?oc=5&hl=en-US&gl=US&ceid=US:en')

      assert_equal(1, @handler.debug_info[:result].count)
    end
  end
end
