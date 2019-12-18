require 'securerandom'

module MulukhiyaTootProxy
  class FilterCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create('filter_command')
      @key = SecureRandom.hex(16)
    end

    def test_handle_pre_toot
      return if invalid_handler?

      @handler.clear
      @handler.handle_pre_toot({message_field => ''})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => "command: filter\ntag: #{@key}"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({message_field => "command: filter\ntag: #{@key}\naction: register"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({message_field => "command: filter\ntag: #{@key}\naction: unregister"})
      assert(@handler.result[:entries].present?)
    end
  end
end
