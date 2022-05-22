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
      Handler.names.map {|v| Handler.create(v)}.each do |handler|
        assert_kind_of(String, handler.underscore)
      end
    end

    def test_disableable?
      Handler.names.map {|v| Handler.create(v)}.each do |handler|
        assert_boolean(handler.disableable?)
      end
    end

    def test_timeout
      Handler.names.map {|v| Handler.create(v)}.each do |handler|
        assert_predicate(handler.timeout, :positive?)
      end
    end

    def test_summary
      handler = Handler.create(:default_tag)
      handler.handle_toot('テスト', {})
      assert_kind_of(Hash, handler.summary)
    end
  end
end
