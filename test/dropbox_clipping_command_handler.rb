module MulukhiyaTootProxy
  class DropboxClippingCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('dropbox_clipping_command')
    end

    def test_hook_pre_toot
      @handler.clear
      @handler.hook_pre_toot({'status' => ''})
      assert_nil(@handler.result)
      sleep(1)

      @handler.clear
      @handler.hook_pre_toot({'status' => "command: dropbox_clipping\nurl: https://mstdn.b-shock.org/web/statuses/101125535795976504"})
      assert(@handler.result[:entries].present?)
      sleep(1)

      @handler.clear
      @handler.hook_pre_toot({'status' => "command: dropbox_clipping\nurl: https://precure.ml/@pooza/101276312982799462"})
      assert(@handler.result[:entries].present?)
      sleep(1)
    end
  end
end
