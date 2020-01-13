module MulukhiyaTootProxy
  class DropboxClippingCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create('dropbox_clipping_command')
    end

    def test_handle_root
      return unless handler?

      @handler.clear
      @handler.handle_root({status_field => ''})
      assert_nil(@handler.result)
      sleep(1)

      @handler.clear
      @handler.handle_root({status_field => "command: dropbox_clipping\nurl: https://mstdn.b-shock.org/web/statuses/101125535795976504"})
      assert(@handler.result[:entries].present?)
      sleep(1)

      @handler.clear
      @handler.handle_root({status_field => "command: dropbox_clipping\nurl: https://precure.ml/@pooza/101276312982799462"})
      assert(@handler.result[:entries].present?)
      sleep(1)
    end
  end
end
