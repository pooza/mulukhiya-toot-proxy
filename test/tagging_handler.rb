module Mulukhiya
  class TaggingHandlerTest < TestCase
    def setup
      @handler = Handler.create('tagging')
    end

    def test_handle_pre_toot
      @handler.handle_pre_toot(status_field => "本文\n本文\n#1行目\n#2行目")
      assert_equal(@handler.payload[status_field], "本文\n本文\n#2行目 #1行目")

      @handler.handle_pre_toot(status_field => "本文\n本文\n#1行目\n#2行目\nhttps://google.co.jp")
      assert_equal(@handler.payload[status_field], "本文\n本文\n#2行目 #1行目\nhttps://google.co.jp")
    end
  end
end
