module MulukhiyaTootProxy
  class GrowiClippingCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('growi_clipping_command')
    end

    def test_parse
      assert_nil(@handler.parse(''))
      assert_nil(@handler.parse('123'))
      assert_equal(@handler.parse('{"command": growi_clipping}'), {'command' => 'growi_clipping'})
      assert_equal(@handler.parse('command: growi_clipping'), {'command' => 'growi_clipping'})
    end

    def test_handle_post_toot
      @handler.clear
      @handler.handle_post_toot({'status' => ''})
      assert_nil(@handler.result)
      sleep(1)

      @handler.clear
      @handler.handle_post_toot({'status' => "command: growi_clipping\nurl: https://mstdn.b-shock.org/web/statuses/101125535795976504"})
      assert(@handler.result[:entries].present?)
      sleep(1)

      @handler.clear
      @handler.handle_post_toot({'status' => "command: growi_clipping\nurl: https://precure.ml/@pooza/101276312982799462"})
      assert(@handler.result[:entries].present?)
      sleep(1)
    end
  end
end
