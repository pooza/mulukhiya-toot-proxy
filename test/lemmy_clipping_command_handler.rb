module Mulukhiya
  class LemmyClippingCommandHandlerTest < TestCase
    def disable?
      return true unless controller_class.lemmy?
      return true unless (account.lemmy.login rescue nil)
      return super
    end

    def setup
      @handler = Handler.create(:lemmy_clipping_command)
    end

    def test_handle_toot
      @handler.clear
      @handler.handle_toot(status_field => '')

      assert_nil(@handler.debug_info)
      sleep(1)

      @handler.clear
      @handler.handle_toot(status_field => "command: lemmy_clipping\nurl: https://mstdn.b-shock.org/@pooza/107261745532055084")

      assert_predicate(@handler.debug_info[:result], :present?)
      sleep(1)

      @handler.clear
      @handler.handle_toot(status_field => "command: lemmy_clipping\nurl: https://precure.ml/@pooza/107261745992066604")

      assert_predicate(@handler.debug_info[:result], :present?)
      sleep(1)
    end
  end
end
