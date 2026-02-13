module Mulukhiya
  class PiefedClippingCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create(:piefed_clipping_command)
    end

    def test_command_name
      assert_equal('piefed_clipping', @handler.command_name)
    end
  end
end
