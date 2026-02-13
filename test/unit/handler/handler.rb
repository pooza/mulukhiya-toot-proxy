module Mulukhiya
  class HandlerTest < TestCase
    def test_search
      assert_kind_of(Set, Handler.search(/amazon/))
    end

    def test_names
      assert_kind_of(Set, Handler.names)
      Handler.names do |name|
        assert_kind_of(String, name)
      end
    end

    def test_all
      Handler.all do |handler|
        assert_kind_of(Handler, handler)
      end
    end

    def test_underscore
      Handler.all do |handler|
        assert_kind_of(String, handler.underscore)
      end
    end

    def test_disable?
      Handler.all do |handler|
        assert_boolean(handler.disable?)
      end
    end

    def test_toggleable?
      Handler.all do |handler|
        assert_boolean(handler.toggleable?)
      end
    end

    def test_experimental?
      Handler.all do |handler|
        assert_boolean(handler.experimental?)
      end
    end

    def test_to_h?
      Handler.all do |handler|
        assert_kind_of(Hash, handler.to_h)
      end
    end

    def test_timeout
      Handler.all do |handler|
        assert_predicate(handler.timeout, :positive?)
      end
    end
  end
end
