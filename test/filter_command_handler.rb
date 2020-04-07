require 'securerandom'

module Mulukhiya
  class FilterCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create('filter_command')
      @key = SecureRandom.hex(16)
    end

    def test_handle_toot
      return unless handler?

      @handler.clear
      @handler.handle_toot(status_field => '')
      assert_nil(@handler.summary)

      @handler.clear
      @handler.handle_toot(status_field => "command: filter\ntag: #{@key}")
      assert(@handler.summary[:result].present?)

      @handler.clear
      @handler.handle_toot(status_field => "command: filter\ntag: #{@key}\naction: register")
      assert(@handler.summary[:result].present?)

      @handler.clear
      @handler.handle_toot(status_field => "command: filter\ntag: #{@key}\naction: unregister")
      assert(@handler.summary[:result].present?)
    end
  end
end
