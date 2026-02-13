module Mulukhiya
  class InvalidCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create(:invalid_command)
    end

    def test_handle_pre_toot
      body = {status_field => "command: nonexistent_command\nkey: value"}
      @handler.payload = body

      assert_raises(Ginseng::ValidateError) do
        @handler.handle_pre_toot(body)
      end
    end

    def test_handle_pre_toot_empty_command
      body = {status_field => 'command:'}
      @handler.payload = body

      assert_raises(Ginseng::ValidateError) do
        @handler.handle_pre_toot(body)
      end
    end
  end
end
