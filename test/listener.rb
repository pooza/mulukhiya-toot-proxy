module Mulukhiya
  class ListenerTest < TestCase
    def setup
      @listener = Environment.listener_class.new
    end

    def test_verify_peer?
      assert_boolean(@listener.verify_peer?)
    end

    def test_root_cert_file
      assert(File.exist?(@listener.root_cert_file))
    end

    def test_keepalive
      assert(@listener.keepalive.positive?)
    end
  end
end
