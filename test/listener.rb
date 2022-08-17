module Mulukhiya
  class ListenerTest < TestCase
    def disable?
      return true unless controller_class.streaming?
      return true unless Environment.daemon_classes.member?(ListenerDaemon)
      return false
    end

    def setup
      @listener = Environment.listener_class.new
    end

    def test_verify_peer?
      assert_boolean(@listener.verify_peer?)
    end

    def test_root_cert_file
      assert_path_exist(@listener.root_cert_file)
    end

    def test_keepalive
      assert_predicate(@listener.keepalive, :positive?)
    end

    def test_underscore
      assert_kind_of(String, @listener.underscore)
    end
  end
end
