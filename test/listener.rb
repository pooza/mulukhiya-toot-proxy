module Mulukhiya
  class ListenerTest < TestCase
    def setup
      @listener = Environment.listener_class.new
    end

    def test_verify_peer?
      assert_boolean(@listener.verify_peer?)
    end

    def test_keepalive
      assert_kind_of(Integer, @listener.keepalive)
    end
  end
end
