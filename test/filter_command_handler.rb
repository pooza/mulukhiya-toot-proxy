require 'securerandom'

module Mulukhiya
  class FilterCommandHandlerTest < TestCase
    def disable?
      return true unless controller_class.filter?
      return super
    end

    def setup
      @handler = Handler.create(:filter_command)
      @key = SecureRandom.hex(16)
    end

    def test_handle_toot
      @handler.clear
      @handler.handle_toot(status_field => '')
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_toot(status_field => "command: filter\ntag: #{@key}")
      assert_predicate(@handler.debug_info[:result], :present?)

      @handler.clear
      @handler.handle_toot(status_field => "command: filter\ntag: #{@key}\naction: register")
      assert_predicate(@handler.debug_info[:result], :present?)

      @handler.clear
      @handler.handle_toot(status_field => "command: filter\ntag: #{@key}\naction: unregister")
      assert_predicate(@handler.debug_info[:result], :present?)
    end
  end
end
